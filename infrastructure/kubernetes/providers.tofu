terraform {
  required_providers {
    talos = {
        version = "0.9.0"
        source = "siderolabs/talos" 
    }
    proxmox = {
        version = "0.88.0"
        source = "bpg/proxmox"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "3.1.0"
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
  host = try(module.talos.kube_config.kubernetes_client_configuration.host, null)
  client_certificate = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate), null)
  client_key = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key), null)
  cluster_ca_certificate = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate), null)
}

provider "helm" {
  kubernetes = {
    host = try(module.talos.kube_config.kubernetes_client_configuration.host, null)
    client_certificate = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate), null)
    client_key = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key), null)
    cluster_ca_certificate = try(base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate), null)
  }
}