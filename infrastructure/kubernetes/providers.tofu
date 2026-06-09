terraform {
  required_providers {
    talos = {
        version = "0.11.0"
        source = "siderolabs/talos" 
    }
    proxmox = {
        version = "0.109.0"
        source = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox.endpoint
  username  = var.proxmox.username
  password  = var.proxmox.password
  insecure  = var.proxmox.insecure
  #api_token = var.proxmox.api_token
  ssh {
    agent = true
  }
}

