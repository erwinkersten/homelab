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
  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.proxmox-csi-role.role_id
  }
}

resource "proxmox_virtual_environment_user_token" "proxmox-csi-user-token" {
  comment               = "Token for Proxmox CSI Plugin"
  token_name            = "csi"
  user_id               = proxmox_virtual_environment_user.proxmox-csi-user.user_id
  privileges_separation = false
}

resource "kubernetes_namespace" "proxmox-csi-namespace" {
  metadata {
    name = "csi-proxmox"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }
}

resource "kubernetes_secret" "proxmox-csi-plugin-secret" {
  metadata {
    name      = "proxmox-csi-plugin"
    namespace = kubernetes_namespace.proxmox-csi-namespace.id
  }

  data = {
    "config.yaml" = <<EOF
clusters:
- url: "${var.proxmox.endpoint}/api2/json"
  insecure: ${var.proxmox.insecure}
  token_id: "${proxmox_virtual_environment_user_token.proxmox-csi-user-token.id}"
  token_secret: "${element(split("=", proxmox_virtual_environment_user_token.proxmox-csi-user-token.value), length(split("=", proxmox_virtual_environment_user_token.proxmox-csi-user-token.value)) - 1)}"
  region: ${var.proxmox.cluster_name}
EOF
  }
}
