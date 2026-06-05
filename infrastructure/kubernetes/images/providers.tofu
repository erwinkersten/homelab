terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.7.1"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.74.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.endpoint
  username = var.proxmox.username
  password = var.proxmox.password
  insecure = var.proxmox.insecure
  ssh {
    agent = true
  }
}
