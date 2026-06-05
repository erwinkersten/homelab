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

# ── Pre-flight: handle resources that exist outside Terraform state ─────────────

PROXMOX_URL=$(grep -E 'endpoint\s*=' "$TFVARS" | head -1 | sed 's/.*"\(.*\)".*/\1/')
API_TOKEN=$(grep -E 'api_token\s*=' "$TFVARS" | head -1 | sed 's/.*"\(.*\)".*/\1/')

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
