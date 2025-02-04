
module "talos" {
  source = "./talos"
  
  providers = {
    proxmox = proxmox
  }

  # Inject Talos Images variables from the *.auto.tfvars file.
  image = {
    version           = var.image.version
    update_version    = var.image.update_version
    schematic         = file("${path.module}/${var.image.schematic}")
    proxmox_iso_ds    = var.image.proxmox_iso_ds
    proxmox_node      = var.image.proxmox_node
  }

  # Reference Cilium (CNI) inlineManifests for control plane nodes.
  cilium = {
    values  = file("${path.module}/../../kubernetes/core/network/cilium/values.yaml")
    install = file("${path.module}/talos/inline-manifests/cilium-install.yaml")
  }

  # Inject cluster variables from the *.auto.tfvars file.
  cluster = var.cluster

  # Inject all nodes from the *.auto.tfvars file.
  nodes = var.nodes
}

module "sealed_secrets" {
  depends_on = [module.talos]
  source = "./bootstrap/sealed-secrets"

  providers = {
    kubernetes = kubernetes
  }

  # openssl req -x509 -days 365 -nodes -newkey rsa:4096 -keyout sealed-secrets.key -out sealed-secrets.cert -subj "/CN=sealed-secret/O=sealed-secret"
  certificate = {
    cert = file("${path.module}/../../config/${var.cluster.environment}/certificates/sealed-secrets.cert")
    key = file("${path.module}/../../config/${var.cluster.environment}/certificates/sealed-secrets.key")
  }
}

module "proxmox_csi_plugin" {
  depends_on = [module.talos]
  source = "./bootstrap/proxmox-csi-plugin"

  providers = {
    proxmox = proxmox
    kubernetes = kubernetes
  }

  proxmox = var.proxmox
}

# module "argocd" {
#   depends_on = [module.talos]
#   source = "./bootstrap/argocd"

#   providers = {
#     helm = helm
#     kubernetes = kubernetes
#   }
  
#   argocd = var.argocd 
# }