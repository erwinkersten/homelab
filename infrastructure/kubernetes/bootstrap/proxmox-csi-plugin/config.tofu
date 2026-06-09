resource "proxmox_virtual_environment_role" "proxmox-csi-role" {
  role_id = "CSI"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit"
  ]
}

resource "proxmox_virtual_environment_user" "proxmox-csi-user" {
  user_id = "kubernetes-csi@pve"
  comment = "User for Proxmox CSI Plugin"
}

resource "proxmox_acl" "proxmox-csi-user-acl" {
  user_id   = proxmox_virtual_environment_user.proxmox-csi-user.user_id
  role_id   = proxmox_virtual_environment_role.proxmox-csi-role.role_id
  path      = "/"
  propagate = true
}

resource "proxmox_user_token" "proxmox-csi-user-token" {
  comment               = "Token for Proxmox CSI Plugin"
  token_name            = "csi"
  user_id               = proxmox_virtual_environment_user.proxmox-csi-user.user_id
  privileges_separation = false
}

output "token_id" {
  value = proxmox_user_token.proxmox-csi-user-token.id
}

output "token_secret" {
  # bpg/proxmox provider returns "<tokenid>=<uuid>" in .value — the CSI plugin
  # expects only the uuid in token_secret, so strip the "<tokenid>=" prefix.
  value     = split("=", proxmox_user_token.proxmox-csi-user-token.value)[1]
  sensitive = true
}
