#!/bin/bash
# Script to import VMs into tofu while skipping health checks
# Usage: ./tofu-import-skip-health.sh [dev|prod]

SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

ENV=$1

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

tofu workspace select $ENV || tofu workspace new $ENV

echo "Importing VMs with health checks disabled..."

# Import all VMs (adjust VM IDs according to your setup)
VMs=(
  "k8-prod-ctrl-00:500:pve-01"
  "k8-prod-ctrl-01:501:pve-01"
  "k8-prod-ctrl-02:502:pve-01"  
  "k8-prod-work-00:503:pve-01"
  "k8-prod-work-01:504:pve-01"
  "k8-prod-work-02:505:pve-01"
)

for vm_config in "${VMs[@]}"; do
  IFS=':' read -r vm_name vm_id node_name <<< "$vm_config"
  
  echo "Importing ${vm_name} (ID: ${vm_id}) on ${node_name}..."
  
  tofu import \
    -var-file="environment.${ENV}.tfvars" \
    -var="skip_health_check=true" \
    "module.talos.proxmox_virtual_environment_vm.this[\"${vm_name}\"]" \
    "${node_name}/${vm_id}"
    
  if [ $? -eq 0 ]; then
    echo "✅ Successfully imported ${vm_name}"
  else
    echo "❌ Failed to import ${vm_name}"
  fi
done

echo "Import process completed!"