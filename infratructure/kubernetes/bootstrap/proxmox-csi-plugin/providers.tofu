terraform {
  required_providers {
    proxmox = {
        version = ">=0.69.1"
        source = "bpg/proxmox"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">=2.35.1"
    }
  }
}
