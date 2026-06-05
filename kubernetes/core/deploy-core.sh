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

# Wait for the API server to accept connections before running kubectl commands
# that depend on a stable connection (rollout status, wait, etc.).
wait_for_api() {
  local attempts=0
  until kubectl get --raw /healthz &>/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ $attempts -gt 36 ]]; then
      echo "ERROR: API server not responding after 3 minutes"
      exit 1
    fi
    echo "  API server not yet responsive — retrying in 5s... (${attempts}/36)"
    sleep 5
  done
}

echo "==> Gateway API CRDs"
kubectl apply --server-side -k crds

echo "==> Cilium (CNI + L2 announcements + IP pool)"
kustomize build --enable-helm network/cilium | kubectl apply --server-side --force-conflicts -f -

echo "==> Waiting for Cilium to be ready"
wait_for_api
kubectl rollout status daemonset/cilium -n kube-system --timeout=300s
kubectl rollout status deployment/cilium-operator -n kube-system --timeout=120s

echo "==> Cilium IP pool and L2 announcement policy"
# Applied after Cilium is ready so its CRDs (CiliumLoadBalancerIPPool,
# CiliumL2AnnouncementPolicy) are established before these resources are created.
kubectl apply -f network/cilium/ciliumLoadBalancerIPPool.yaml
kubectl apply -f network/cilium/ciliumL2AnnouncementPolicy.yaml

echo "==> Sealed-Secrets controller"
# Must run before cert-manager so the SealedSecret containing the Cloudflare
# API token is unsealed in time for the ClusterIssuer to use it.
kustomize build --enable-helm controllers/sealed-secrets | kubectl apply --server-side --force-conflicts -f -

echo "==> Waiting for Sealed-Secrets controller to be ready"
wait_for_api
kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets --timeout=120s

echo "==> Cert-manager"
# Must run before Gateway so the Certificate CRD exists when gateway is applied.
kustomize build --enable-helm controllers/cert-manager | kubectl apply --server-side --force-conflicts -f -

echo "==> Waiting for cert-manager CRDs to be established"
wait_for_api
kubectl wait --for=condition=established --timeout=120s \
  crd/clusterissuers.cert-manager.io \
  crd/certificates.cert-manager.io \
  crd/certificaterequests.cert-manager.io

echo "==> Waiting for cert-manager webhook to be ready"
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "==> Waiting for Cloudflare API token secret to be unsealed"
until kubectl get secret cloudflare-api-token-secret -n cert-manager &>/dev/null; do
  sleep 5
done

echo "==> Cert-manager ClusterIssuer"
kubectl apply -f controllers/cert-manager/cm-cluster-issuer.yaml

echo "==> Gateway API resources"
kustomize build --enable-helm network/gateway | kubectl apply --server-side --force-conflicts -f -

echo "==> ArgoCD"
# --server-side avoids the 262144-byte annotation limit on ArgoCD's large CRDs.
kustomize build --enable-helm controllers/argocd | kubectl apply --server-side --force-conflicts -f -

echo "==> Proxmox CSI plugin"
kustomize build --enable-helm storage/csi-proxmox | kubectl apply --server-side --force-conflicts -f -

echo ""
echo "Core components deployed. Activate GitOps with:"
echo "  kubectl apply -k kubernetes/argo-apps/"
