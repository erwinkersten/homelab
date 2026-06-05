#!/bin/bash

# Prepares the config/{env}/ directory before the first tofu apply.
# Safe to run multiple times — existing certificates are never overwritten.
#
# Usage: ./setup-config.sh [dev|prod]

set -euo pipefail

ENV=$1

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../../config/${ENV}"
CERT_DIR="${CONFIG_DIR}/certificates"

# ── Directory structure ────────────────────────────────────────────────────────
echo "Creating config directory structure for environment: ${ENV}"
mkdir -p "${CERT_DIR}"

# ── Sealed Secrets certificate ─────────────────────────────────────────────────
# This certificate is loaded by main.tofu during the plan phase — it must exist
# before running tofu apply. It is gitignored, so it must be generated once per
# environment after a fresh clone.
#
# The public certificate is also used by kubeseal when encrypting secrets:
#   kubeseal --cert config/${ENV}/certificates/sealed-secrets.cert ...

if [[ -f "${CERT_DIR}/sealed-secrets.cert" && -f "${CERT_DIR}/sealed-secrets.key" ]]; then
  echo "Sealed secrets certificates already exist — skipping generation."
  echo "  ${CERT_DIR}/sealed-secrets.cert"
  echo "  ${CERT_DIR}/sealed-secrets.key"
else
  echo "Generating sealed secrets certificates (RSA 4096, valid 10 years)..."

  if ! command -v openssl &>/dev/null; then
    echo "ERROR: openssl is not installed or not in PATH"
    exit 1
  fi

  openssl req -x509 -days 3650 -nodes -newkey rsa:4096 \
    -keyout "${CERT_DIR}/sealed-secrets.key" \
    -out    "${CERT_DIR}/sealed-secrets.cert" \
    -subj   "/CN=sealed-secret/O=sealed-secret" 2>/dev/null

  chmod 600 "${CERT_DIR}/sealed-secrets.key"
  chmod 644 "${CERT_DIR}/sealed-secrets.cert"

  echo "Certificates generated:"
  echo "  ${CERT_DIR}/sealed-secrets.cert  (public — share with kubeseal)"
  echo "  ${CERT_DIR}/sealed-secrets.key   (private — keep safe, never commit)"
fi

echo ""
echo "Config directory ready: ${CONFIG_DIR}"
echo ""
echo "Files created by tofu apply (no action needed now):"
echo "  config/${ENV}/talos-config.yaml"
echo "  config/${ENV}/kube-config.yaml"
echo "  config/${ENV}/talos-machine-config-<node>.yaml"
