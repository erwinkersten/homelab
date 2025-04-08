#!/bin/bash

ENV=$1

# Check if the environment variable is set and valid
if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi


tofu workspace select $ENV || tofu workspace new $ENV
tofu taint module.proxmox_csi_plugin.kubernetes_secret.proxmox-csi-plugin-secret
tofu apply -var-file="environment.${ENV}.tfvars" -target="module.proxmox_csi_plugin.kubernetes_secret.proxmox-csi-plugin-secret"