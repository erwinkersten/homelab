variable "proxmox" {
  description = "Proxmox Configuration"
  type = object({
    endpoint     = string
    username     = string
    password     = string
    insecure     = bool
    api_token    = string
    cluster_name = string
  })
  sensitive = true
}

variable "image" {
  description = "Talos Image Configuration"
  type = object({
    version          = string
    update_version   = string
    schematic        = string
    proxmox_iso_ds   = string
    proxmox_node     = string
  })
}

variable "cluster" {
  description = "Cluster Configuration"
  type = object({
    name            = string
    environment     = string
    endpoint        = string
    gateway         = string
    cidr            = string
    proxmox_cluster = string
    talos_version   = string
  })
}

variable "nodes" { 
  description = "Node Configuration"
  type = map(object({
    machine_type  = string
    update        = optional(bool, false)
    ip            = string
    cidr          = string
    gateway       = string
    cpu           = number
    disk_size     = number
    ram_dedicated = string
    host_node     = string
    vm_id         = number
    datastore_id  = string
  }))
}

variable "argocd" {
  description = "ArgoCD Configuration"
  type = object({
    name      = string
    namespace = string
  })
}

# variable "cilium" {
#   description = "Cilium Configuration"
#   type = object({
#     values  = string
#     install = string
#   })
# }
