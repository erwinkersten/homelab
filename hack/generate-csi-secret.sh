#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

ENV=$1

# Check if the environment variable is set and valid
if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

# Change to the script's directory to ensure relative paths work
cd "$SCRIPT_DIR/../infrastructure/kubernetes" || exit 1

tofu workspace select $ENV || tofu workspace new $ENV
tofu taint kubernetes_secret.proxmox-csi-plugin-secret
tofu apply -var-file="environment.${ENV}.tfvars" -target="module.proxmox_csi_plugin.kubernetes_secret.proxmox-csi-plugin-secret"