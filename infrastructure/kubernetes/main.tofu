data "external" "check_proxmox" {
  count = var.import_mode ? 0 : 1

  program = [
    "bash",
    "${path.module}/bootstrap/proxmox-csi-plugin/scripts/check-role.sh",
    "CSI",
    "kubernetes-csi@pve",
    var.proxmox.endpoint,
    var.proxmox.api_token
  ]
}

module "talos" {
  source = "./talos"

  providers = {
    proxmox = proxmox
  }

  image = {
    file_id         = var.image.file_id
    update_file_id  = var.image.update_file_id
    installer_image = var.image.installer_image
  }

  cilium = {
    values  = file("${path.module}/../../kubernetes/core/network/cilium/values.yaml")
    install = file("${path.module}/talos/inline-manifests/cilium-install.yaml")
  }

  cluster = var.cluster
  nodes   = var.nodes

  import_mode = var.import_mode
}

module "sealed_secrets" {
  count = var.import_mode ? 0 : 1

  depends_on = [module.talos]
  source     = "./bootstrap/sealed-secrets"

  providers = {
    kubernetes = kubernetes
  }

  certificate = {
    cert = file("${path.module}/../../config/${var.cluster.environment}/certificates/sealed-secrets.cert")
    key  = file("${path.module}/../../config/${var.cluster.environment}/certificates/sealed-secrets.key")
  }
}

module "proxmox_csi_plugin" {
  count = var.import_mode ? 0 : 1

  depends_on = [module.talos]
  source     = "./bootstrap/proxmox-csi-plugin"

  providers = {
    proxmox    = proxmox
    kubernetes = kubernetes
  }

  proxmox             = var.proxmox
  role_already_exists = var.import_mode ? false : data.external.check_proxmox[0].result.role_exists == "true"
  user_already_exists = var.import_mode ? false : data.external.check_proxmox[0].result.user_exists == "true"
}

