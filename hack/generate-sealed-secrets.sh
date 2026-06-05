#!/bin/bash
# Seals all *_encrypt files into SealedSecrets using the in-cluster controller.
#
# Prerequisites:
#   - KUBECONFIG set and pointing at a running cluster with Sealed Secrets installed
#   - kubeseal installed: https://github.com/bitnami-labs/sealed-secrets#installation
#
# Setup (first time):
#   Copy each *.yaml_encrypt.example to *.yaml_encrypt alongside it, then fill
#   in the real secret values. The _encrypt files are gitignored and never committed.
#
#   kubernetes/apps/homepage/homepage-secret.yaml_encrypt
#   kubernetes/infra/observability/kube-prometheus-stack/grafana-admin-secret.yaml_encrypt
#   kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml_encrypt

set -euo pipefail

if [[ -z "${KUBECONFIG:-}" ]]; then
  echo "ERROR: KUBECONFIG is not set."
  echo "Export the kubeconfig before running this script:"
  echo "  export KUBECONFIG=\$(pwd)/../config/prod/kube-config.yaml"
  exit 1
fi

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal is not installed or not in PATH"
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

echo "Regenerating sealed secrets"

kubeseal --format yaml --controller-namespace sealed-secrets \
  < ../kubernetes/apps/homepage/homepage-secret.yaml_encrypt \
  > ../kubernetes/apps/homepage/homepage-secret.yaml

kubeseal --format yaml --controller-namespace sealed-secrets \
  < ../kubernetes/infra/observability/kube-prometheus-stack/grafana-admin-secret.yaml_encrypt \
  > ../kubernetes/infra/observability/kube-prometheus-stack/grafana-admin-secret.yaml

kubeseal --format yaml --controller-namespace sealed-secrets \
  < ../kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml_encrypt \
  > ../kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml

echo "Done. The sealed YAML files can be committed to git."
