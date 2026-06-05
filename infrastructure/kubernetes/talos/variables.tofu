variable "image" {
  description = "Talos image file references. Obtain file_id and installer_image from tofu-images.sh output."
  type = object({
    file_id          = string           # Proxmox file ID for the current image, e.g. "data:iso/talos-...-v1.9.1-nocloud-amd64.img"
    update_file_id   = optional(string) # Proxmox file ID for the upgrade image; falls back to file_id when not set
    installer_image  = optional(string) # Full installer URL for talosctl upgrade, e.g. "factory.talos.dev/installer/{schematic}:v1.9.3"
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
    talos_version      = string
    kubernetes_version = string # must be compatible with talos_version — see https://www.talos.dev/latest/introduction/support-matrix/
    proxmox_cluster    = string
    bootstrap_node     = string # IP of the control plane node used for bootstrap and kubeconfig retrieval
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
    update        = optional(bool, false)
    disk_size     = number
  }))
}

variable "cilium" {
  description = "Cilium CNI configuration injected as inline manifests"
  type = object({
    values  = string
    install = string
  })
}

variable "import_mode" {
  description = "When true, skips cluster bootstrapping (machine config apply, health check, ArgoCD, etc.) to allow safe VM import into state."
  type        = bool
  default     = false
}
