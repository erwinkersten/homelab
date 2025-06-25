terraform {
  required_providers {
    talos = {
        version = "0.7.1"
        source = "siderolabs/talos" 
    }
    proxmox = {
        version = "0.74.1"
        source = "bpg/proxmox"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
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

provider "kubernetes" {
  host = module.talos.kube_config.kubernetes_client_configuration.host
  client_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
  client_key = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
}

provider "helm" {
  kubernetes {
    host = module.talos.kube_config.kubernetes_client_configuration.host
    client_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
    client_key = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
  }
}