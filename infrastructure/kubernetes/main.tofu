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

module "proxmox_csi_plugin" {
  count = var.import_mode ? 0 : 1

  source = "./bootstrap/proxmox-csi-plugin"

  providers = {
    proxmox = proxmox
  }

  proxmox = var.proxmox
}
