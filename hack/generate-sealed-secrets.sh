#!/bin/bash
# Seals all *_encrypt files into SealedSecrets, OFFLINE, against the persisted
# public certificate at config/<env>/certificates/sealed-secrets.cert.
#
# Why --cert (offline) and not the live controller:
#   tofu bootstrap loads config/<env>/certificates/sealed-secrets.{cert,key}
#   into every (re)built cluster as the active controller key. Sealing against
#   the live controller instead binds the SealedSecret to whatever key the
#   controller happens to have at seal time, which drifts from the persisted
#   key — so secrets sealed that way fail to decrypt after a cluster rebuild
#   (e.g. grafana-admin-secret never materializes and Grafana hangs).
#   Sealing offline against the persisted cert makes the output deterministic
#   and decryptable on any cluster bootstrapped with the same key.
#
# Usage: ./generate-sealed-secrets.sh [dev|prod]   (default: prod)
#
# Setup (first time):
#   Copy each *.yaml_encrypt.example to *.yaml_encrypt alongside it, then fill
#   in the real secret values. The _encrypt files are gitignored and never committed.
#
#   kubernetes/apps/homepage/homepage-secret.yaml_encrypt
#   kubernetes/infra/observability/kube-prometheus-stack/grafana-admin-secret.yaml_encrypt
#   kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml_encrypt

set -euo pipefail

ENV="${1:-prod}"

if [[ ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
CERT="${SCRIPT_DIR}/../config/${ENV}/certificates/sealed-secrets.cert"
# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal is not installed or not in PATH"
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

if [[ ! -f "$CERT" ]]; then
  echo "ERROR: sealed-secrets certificate not found:"
  echo "  $CERT"
  echo "Generate it first with: infrastructure/kubernetes/setup-config.sh ${ENV}"
  exit 1
fi

echo "Regenerating sealed secrets (offline, cert: config/${ENV}/certificates/sealed-secrets.cert)"

kubeseal --format yaml --cert "$CERT" \
  < ../kubernetes/apps/homepage/homepage-secret.yaml_encrypt \
  > ../kubernetes/apps/homepage/homepage-secret.yaml

kubeseal --format yaml --cert "$CERT" \
  < ../kubernetes/infra/observability/kube-prometheus-stack/grafana-admin-secret.yaml_encrypt \
  > ../kubernetes/infra/observability/kube-prometheus-stack/grafana-admin-secret.yaml

kubeseal --format yaml --cert "$CERT" \
  < ../kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml_encrypt \
  > ../kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml

echo "Done. The sealed YAML files can be committed to git."
