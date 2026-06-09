#!/bin/bash
# Deploys core cluster components in dependency order.
# Called automatically by tofu-deploy.sh after tofu apply.
# Can also be re-run standalone: cd kubernetes/core && ./deploy-core.sh
# Requires: kubectl, kustomize, helm — and KUBECONFIG pointing at the cluster.

set -euo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  echo "ERROR: KUBECONFIG is not set."
  echo "Export the kubeconfig before running this script:"
  echo "  export KUBECONFIG=\$(pwd)/../../config/prod/kube-config.yaml"
  exit 1
fi

# Derive the per-environment config directory from KUBECONFIG path.
# e.g. config/prod/kube-config.yaml  →  config/prod
CONFIG_DIR="$(dirname "$KUBECONFIG")"

# Wait for the API server to be fully functional — not just alive.
# Uses "kubectl get nodes" rather than /healthz: /healthz is an unauthenticated
# stub that responds even when the API is too overloaded for real requests,
# causing rollout status / kubectl wait to immediately fail with TLS timeout.
wait_for_api() {
  local attempts=0
  until kubectl get nodes &>/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ $attempts -gt 36 ]]; then
      echo "ERROR: Kubernetes API not ready after 3 minutes"
      exit 1
    fi
    echo "  API server not yet responsive — retrying in 5s... (${attempts}/36)"
    sleep 5
  done
}

# Retry a command up to 12 times to absorb brief API blips (TLS timeouts,
# connection resets) that can occur immediately after a large Helm apply.
with_retry() {
  local attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 12 ]]; then
      echo "ERROR: Command still failing after $attempts attempts: $*"
      return 1
    fi
    fi
    echo "  Retrying in 5s... (attempt $attempts/12)"
    sleep 5
  done
}

# Apply a manifest supplied on stdin, with retries.
# Usage: apply_manifest <<EOF ... EOF
apply_manifest() {
  local manifest
  manifest=$(cat)
  local attempts=0
  until echo "$manifest" | kubectl apply -f -; do
    attempts=$((attempts + 1))
    if [[ $attempts -gt 12 ]]; then
      echo "ERROR: kubectl apply failed after $attempts attempts"
      return 1
    fi
    echo "  Retrying in 5s... (attempt $attempts/12)"
    sleep 5
  done
}

echo "==> Waiting for Kubernetes API to be ready"
# Talos internal health passes before the external API at :6443 is fully stable.
# During kubelet cert rotation right after bootstrap the API oscillates — single
# checks pass but sustained 5-in-a-row never completes. We wait for one success
# and then rely on with_retry to absorb subsequent blips.
wait_for_api

# Build a kustomize directory and apply it as a retryable unit.
# Captures build output so kubectl can be retried without re-running kustomize.
apply_kustomize() {
  local dir="$1"
  local output
  output=$(kustomize build --enable-helm "$dir")
  echo "$output" | kubectl apply --server-side --force-conflicts -f -
}

echo "==> Gateway API CRDs"
with_retry kubectl apply --server-side -k crds

echo "==> Cilium (CNI + L2 announcements + IP pool)"
with_retry apply_kustomize network/cilium

echo "==> Waiting for Cilium to be ready"
wait_for_api
with_retry kubectl rollout status daemonset/cilium -n kube-system --timeout=300s
with_retry kubectl rollout status deployment/cilium-operator -n kube-system --timeout=120s

echo "==> Cilium IP pool and L2 announcement policy"
# Applied after Cilium is ready so its CRDs (CiliumLoadBalancerIPPool,
# CiliumL2AnnouncementPolicy) are established before these resources are created.
with_retry kubectl apply -f network/cilium/ciliumLoadBalancerIPPool.yaml
with_retry kubectl apply -f network/cilium/ciliumL2AnnouncementPolicy.yaml

echo "==> Sealed-Secrets namespace and bootstrap key"
# The bootstrap key must exist before the controller starts so it picks up the
# persisted keypair rather than generating a new one that would be lost on destroy.
# This was previously done by OpenTofu but moved here to avoid Kubernetes provider
# TLS timeouts during the turbulent bootstrap window.
SEALED_SECRETS_CERT="${CONFIG_DIR}/certificates/sealed-secrets.cert"
SEALED_SECRETS_KEY="${CONFIG_DIR}/certificates/sealed-secrets.key"
if [[ ! -f "$SEALED_SECRETS_CERT" || ! -f "$SEALED_SECRETS_KEY" ]]; then
  echo "ERROR: Sealed-Secrets cert/key not found in ${CONFIG_DIR}/certificates (run setup-config.sh first)"
  exit 1
fi
apply_manifest <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: sealed-secrets
EOF
apply_manifest <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: sealed-secrets-bootstrap-key
  namespace: sealed-secrets
  labels:
    sealedsecrets.bitnami.com/sealed-secrets-key: "active"
data:
  tls.crt: $(base64 -w0 < "${CONFIG_DIR}/certificates/sealed-secrets.cert")
  tls.key: $(base64 -w0 < "${CONFIG_DIR}/certificates/sealed-secrets.key")
EOF

echo "==> Sealed-Secrets controller"
# Must run before cert-manager so the SealedSecret containing the Cloudflare
# API token is unsealed in time for the ClusterIssuer to use it.
with_retry apply_kustomize controllers/sealed-secrets

echo "==> Waiting for Sealed-Secrets controller to be ready"
wait_for_api
with_retry kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets --timeout=120s

echo "==> Cert-manager"
# Must run before Gateway so the Certificate CRD exists when gateway is applied.
with_retry apply_kustomize controllers/cert-manager

echo "==> Waiting for cert-manager CRDs to be established"
wait_for_api
with_retry kubectl wait --for=condition=established --timeout=120s \
  crd/clusterissuers.cert-manager.io \
  crd/certificates.cert-manager.io \
  crd/certificaterequests.cert-manager.io

echo "==> Waiting for cert-manager webhook to be ready"
with_retry kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "==> Waiting for Cloudflare API token secret to be unsealed"
until with_retry kubectl get secret cloudflare-api-token-secret -n cert-manager &>/dev/null; do
  sleep 5
done

echo "==> Cert-manager ClusterIssuer"
with_retry kubectl apply -f controllers/cert-manager/cm-cluster-issuer.yaml

echo "==> Gateway API resources"
with_retry apply_kustomize network/gateway

echo "==> Waiting for TLS wildcard certificate"
# Let cert-manager issue normally. If Let's Encrypt rate-limits us (5 certs per
# exact identifier set per 7 days — easy to hit across cluster rebuilds) and a
# saved certificate exists, restore it so the gateway becomes valid immediately.
TLS_BACKUP="${CONFIG_DIR}/tls-wildcard-cert.yaml"
cert_ready=false
for i in $(seq 1 24); do  # 24 × 10 s = 4 minutes
  cert_status=$(kubectl get certificate wildcard-cert-local-erwinkersten-com \
    -n gateway -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  if [[ "$cert_status" == "True" ]]; then
    cert_ready=true
    break
  fi
  # Detect Let's Encrypt rate-limit error in the Certificate conditions
  cert_message=$(kubectl get certificate wildcard-cert-local-erwinkersten-com \
    -n gateway -o jsonpath='{.status.conditions[*].message}' 2>/dev/null || true)
  if echo "$cert_message" | grep -qi "rateLimited\|too many certificates\|rate limit"; then
    echo "  Let's Encrypt rate limit detected."
    if [[ -f "$TLS_BACKUP" ]]; then
      echo "  Restoring certificate from backup — cert-manager will use the existing secret."
      apply_manifest < "$TLS_BACKUP"
      cert_ready=true
    else
      echo "  WARNING: No backup found. Check 'kubectl describe certificate -n gateway' for retry time."
    fi
    break
  fi
  echo "  Waiting for TLS certificate... ($i/24)"
  sleep 10
done
if [[ "$cert_ready" != "true" ]]; then
  echo "  WARNING: TLS certificate not yet ready — gateway will be unprogrammed until it is issued."
  echo "  Check: kubectl get certificate -n gateway"
fi

echo "==> ArgoCD"
# --server-side avoids the 262144-byte annotation limit on ArgoCD's large CRDs.
with_retry apply_kustomize controllers/argocd

echo "==> Proxmox CSI namespace and plugin secret"
# The plugin secret must exist before the Helm chart is applied so the CSI driver
# can start. The config.yaml content is written by OpenTofu to config/${ENV}/csi-config.yaml.
CSI_CONFIG_FILE="${CONFIG_DIR}/csi-config.yaml"
if [[ ! -f "$CSI_CONFIG_FILE" ]]; then
  echo "ERROR: CSI config not found at $CSI_CONFIG_FILE"
  echo "Run tofu-deploy.sh first to generate it."
  exit 1
fi
apply_manifest <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: csi-proxmox
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
EOF
apply_manifest <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: proxmox-csi-plugin
  namespace: csi-proxmox
type: Opaque
data:
  config.yaml: $(base64 -w0 < "${CSI_CONFIG_FILE}")
EOF

echo "==> Proxmox CSI plugin"
with_retry apply_kustomize storage/csi-proxmox

echo "==> Saving TLS wildcard certificate backup"
# Save the issued certificate so it can be restored on the next rebuild if
# Let's Encrypt rate-limits a fresh issuance. The file is gitignored.
TLS_BACKUP="${CONFIG_DIR}/tls-wildcard-cert.yaml"
save_attempts=0
until kubectl get secret wildcard-cert-local-erwinkersten-com -n gateway &>/dev/null 2>&1; do
  save_attempts=$((save_attempts + 1))
  if [[ $save_attempts -gt 12 ]]; then  # 12 × 10 s = 2 minutes
    echo "  TLS secret not yet available — run this after it is issued:"
    echo "    TLS_CRT=\$(kubectl get secret wildcard-cert-local-erwinkersten-com -n gateway -o jsonpath='{.data.tls\\.crt}')"
    echo "    TLS_KEY=\$(kubectl get secret wildcard-cert-local-erwinkersten-com -n gateway -o jsonpath='{.data.tls\\.key}')"
    break
  fi
  echo "  Waiting for TLS secret... ($save_attempts/12)"
  sleep 10
done
if kubectl get secret wildcard-cert-local-erwinkersten-com -n gateway &>/dev/null 2>&1; then
  TLS_CRT=$(kubectl get secret wildcard-cert-local-erwinkersten-com \
    -n gateway -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
  TLS_KEY=$(kubectl get secret wildcard-cert-local-erwinkersten-com \
    -n gateway -o jsonpath='{.data.tls\.key}' 2>/dev/null)
  cat > "$TLS_BACKUP" <<TLSEOF
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: wildcard-cert-local-erwinkersten-com
  namespace: gateway
data:
  tls.crt: ${TLS_CRT}
  tls.key: ${TLS_KEY}
TLSEOF
  chmod 600 "$TLS_BACKUP"
  echo "  Saved to $(basename "$CONFIG_DIR")/tls-wildcard-cert.yaml"
fi

echo ""
echo "Core components deployed. Activate GitOps with:"
echo "  kubectl apply -k kubernetes/argo-apps/"
