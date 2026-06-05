locals {
  role_id = var.role_already_exists ? "CSI" : proxmox_virtual_environment_role.proxmox-csi-role[0].role_id
  user_id = var.user_already_exists ? "kubernetes-csi@pve" : proxmox_virtual_environment_user.proxmox-csi-user[0].user_id
}

resource "proxmox_virtual_environment_role" "proxmox-csi-role" {
  count   = var.role_already_exists ? 0 : 1
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
  count   = var.user_already_exists ? 0 : 1
  user_id = "kubernetes-csi@pve"
  comment = "User for Proxmox CSI Plugin"
}

resource "proxmox_acl" "proxmox-csi-user-acl" {
  user_id   = local.user_id
  role_id   = local.role_id
  path      = "/"
  propagate = true
}

resource "proxmox_user_token" "proxmox-csi-user-token" {
  comment               = "Token for Proxmox CSI Plugin"
  token_name            = "csi"
  user_id               = local.user_id
  privileges_separation = false
}

resource "kubernetes_namespace_v1" "proxmox-csi-namespace" {
  metadata {
    name = "csi-proxmox"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }
}

resource "kubernetes_secret_v1" "proxmox-csi-plugin-secret" {
  metadata {
    name      = "proxmox-csi-plugin"
    namespace = kubernetes_namespace_v1.proxmox-csi-namespace.metadata[0].name
  }

  data = {
    "config.yaml" = <<-EOF
      clusters:
      - url: "${var.proxmox.endpoint}/api2/json"
        insecure: ${var.proxmox.insecure}
        token_id: "${proxmox_user_token.proxmox-csi-user-token.id}"
        token_secret: "${proxmox_user_token.proxmox-csi-user-token.value}"
        region: ${var.proxmox.cluster_name}
    EOF
  }
}
