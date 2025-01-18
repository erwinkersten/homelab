variable "image" {
  description = "Talos image configuration"
  type = object({
    factory_url     = optional(string, "https://factory.talos.dev")
    schematic       = string
    version         = string
    update_schematic = optional(string)
    update_version  = optional(string)
    update_image    = optional(bool, false)
    arch            = optional(string, "amd64")
    platform        = optional(string, "nocloud")
    proxmox_iso_ds  = optional(string, "local")
    proxmox_node    = string
  })
}

variable "cluster" {
  description = "Cluster configuration"
  type = object({
    name            = string
    environment     = string
    endpoint        = string
    gateway         = string
    cidr            = number
    talos_version   = string
    proxmox_cluster = string
  })
}

variable "nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    host_node     = string
    machine_type  = string
    datastore_id  = optional(string, "local-zfs")
    ip            = string
    cidr          = number
    gateway       = string
    vm_id         = number
    cpu           = number
    ram_dedicated = number
    update = optional(bool, false)
    disk_size     = number
  }))
}

variable "cilium" {
  description = "Cilium configuration"
  type = object({
    values  = string
    install = string
  })
}
