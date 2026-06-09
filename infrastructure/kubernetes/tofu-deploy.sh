#!/bin/bash

set -euo pipefail

ENV=$1

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KUBECONFIG_PATH="${SCRIPT_DIR}/../../config/${ENV}/kube-config.yaml"
TFVARS="environment.${ENV}.tfvars"

# Ensure the config directory and sealed secrets certificates exist before
# tofu apply — main.tofu reads the cert files during the plan phase.
"${SCRIPT_DIR}/setup-config.sh" "$ENV"

tofu workspace select "$ENV" || tofu workspace new "$ENV"

# ── Pre-flight: migrate resources removed from OpenTofu state ───────────────────
# Kubernetes namespace and secret resources were moved from OpenTofu modules to
# deploy-core.sh. Remove them from state so tofu apply does not try to destroy
# them (they will be created/managed by kubectl from now on).
for resource in \
  "module.sealed_secrets[0].kubernetes_namespace_v1.sealed-secrets" \
  "module.sealed_secrets[0].kubernetes_secret_v1.sealed-secrets-key" \
  "module.proxmox_csi_plugin[0].kubernetes_namespace_v1.proxmox-csi-namespace" \
  "module.proxmox_csi_plugin[0].kubernetes_secret_v1.proxmox-csi-plugin-secret" \
  "null_resource.wait_for_kubernetes[0]"; do
  if tofu state show "$resource" &>/dev/null 2>&1; then
    echo "Removing migrated resource from state: $resource"
    tofu state rm "$resource"
  fi
done

# ── Pre-flight: handle resources that exist outside Terraform state ─────────────

PROXMOX_URL=$(grep -E 'endpoint\s*=' "$TFVARS" | head -1 | sed 's/.*"\(.*\)".*/\1/')
API_TOKEN=$(grep -E 'api_token\s*=' "$TFVARS" | head -1 | sed 's/.*"\(.*\)".*/\1/')

# CSI role — import if it exists in Proxmox but not in state, so destroy can clean it up.
if ! tofu state show "module.proxmox_csi_plugin[0].proxmox_virtual_environment_role.proxmox-csi-role" &>/dev/null; then
  ROLE_EXISTS=$(curl -sk \
    -H "Authorization: PVEAPIToken=${API_TOKEN}" \
    "${PROXMOX_URL}/api2/json/access/roles" \
    2>/dev/null \
    | jq -r '[.data[] | select(.roleid=="CSI")] | length > 0' 2>/dev/null \
    || echo "false")
  if [[ "$ROLE_EXISTS" == "true" ]]; then
    echo "Pre-existing CSI role found — importing into state..."
    tofu import -var-file="$TFVARS" \
      "module.proxmox_csi_plugin[0].proxmox_virtual_environment_role.proxmox-csi-role" "CSI"
  fi
fi

# CSI user — import if it exists in Proxmox but not in state.
if ! tofu state show "module.proxmox_csi_plugin[0].proxmox_virtual_environment_user.proxmox-csi-user" &>/dev/null; then
  USER_EXISTS=$(curl -sk \
    -H "Authorization: PVEAPIToken=${API_TOKEN}" \
    "${PROXMOX_URL}/api2/json/access/users" \
    2>/dev/null \
    | jq -r '[.data[] | select(.userid=="kubernetes-csi@pve")] | length > 0' 2>/dev/null \
    || echo "false")
  if [[ "$USER_EXISTS" == "true" ]]; then
    echo "Pre-existing CSI user found — importing into state..."
    tofu import -var-file="$TFVARS" \
      "module.proxmox_csi_plugin[0].proxmox_virtual_environment_user.proxmox-csi-user" "kubernetes-csi@pve"
  fi
fi

# CSI user token — must be deleted if it exists in Proxmox but not in state,
# because the token value cannot be recovered after creation.
if ! tofu state show "module.proxmox_csi_plugin[0].proxmox_user_token.proxmox-csi-user-token" &>/dev/null; then
  TOKEN_EXISTS=$(curl -sk \
    -H "Authorization: PVEAPIToken=${API_TOKEN}" \
    "${PROXMOX_URL}/api2/json/access/users/kubernetes-csi%40pve/token/csi" \
    2>/dev/null \
    | jq -r 'if .data != null then "true" else "false" end' 2>/dev/null \
    || echo "false")

  if [[ "$TOKEN_EXISTS" == "true" ]]; then
    echo "Stale CSI token found in Proxmox but not in Terraform state."
    echo "Deleting it so Terraform can create a fresh token with a known value..."
    curl -sk -X DELETE \
      -H "Authorization: PVEAPIToken=${API_TOKEN}" \
      "${PROXMOX_URL}/api2/json/access/users/kubernetes-csi%40pve/token/csi" \
      &>/dev/null || true
    echo "Done."
  fi
fi

# ── Apply ───────────────────────────────────────────────────────────────────────
tofu apply -var-file="$TFVARS" -parallelism=2

# CSI token privilege separation — force privsep=0 so the token inherits the
# kubernetes-csi@pve user's ACL. The provider does not reliably set this, and
# with privsep=1 the token has no permissions and the CSI plugin cannot attach
# disks. Idempotent: setting privsep=0 on an already-0 token is a no-op.
echo "Ensuring CSI token has privilege separation disabled..."
curl -sk -X PUT \
  -H "Authorization: PVEAPIToken=${API_TOKEN}" \
  "${PROXMOX_URL}/api2/json/access/users/kubernetes-csi%40pve/token/csi" \
  --data-urlencode 'privsep=0' \
  &>/dev/null || echo "  WARNING: failed to set privsep=0 on CSI token"

# ── Deploy core cluster components ──────────────────────────────────────────────
# ArgoCD, Cilium full config, Gateway API, Cert-manager, Sealed-Secrets controller,
# and Proxmox CSI plugin are all installed via deploy-core.sh using kustomize + Helm.
export KUBECONFIG="$KUBECONFIG_PATH"
CORE_DIR="${SCRIPT_DIR}/../../kubernetes/core"

echo ""
echo "Running deploy-core.sh..."
(cd "$CORE_DIR" && ./deploy-core.sh)

echo ""
kubectl get nodes
echo ""
echo "Cluster is ready. To activate GitOps run:"
echo "  export KUBECONFIG=\"${KUBECONFIG_PATH}\""
echo "  kubectl apply -k kubernetes/argo-apps/"
