#!/bin/bash

ENV=$1
VM_OVERRIDE="talos/virtual_machines_override.tofu"
SECRETS_OVERRIDE="talos/config_override.tofu"

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

read -r -p "Override prevent_destroy on VMs and machine secrets to allow deletion? [yes/no]: " CONFIRM
if [[ "$CONFIRM" == "yes" ]]; then
  cat > "$VM_OVERRIDE" <<'EOF'
resource "proxmox_virtual_environment_vm" "this" {
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      description,
      tags,
      disk[0].file_id
    ]
  }
}
EOF

  cat > "$SECRETS_OVERRIDE" <<'EOF'
resource "talos_machine_secrets" "this" {
  lifecycle {
    prevent_destroy = false
  }
}
EOF
fi

tofu workspace select $ENV || tofu workspace new $ENV
tofu destroy -var-file="environment.${ENV}.tfvars"

if [[ $? -eq 0 ]]; then
  rm -f "$VM_OVERRIDE" "$SECRETS_OVERRIDE"
fi
