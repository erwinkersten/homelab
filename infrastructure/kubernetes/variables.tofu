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
  description = "Talos image references. Run tofu-images.sh first to populate these values."
  type = object({
    file_id         = string           # Proxmox file ID for the current image
    update_file_id  = optional(string) # Proxmox file ID for the upgrade image
    installer_image = optional(string) # Full installer URL for talosctl upgrade
  })
}

variable "cluster" {
  description = "Cluster Configuration"
  type = object({
    name            = string
    environment     = string
    endpoint        = string
    gateway         = string
    cidr            = number
    proxmox_cluster = string
    talos_version      = string
    kubernetes_version = string # must be compatible with talos_version — see https://www.talos.dev/latest/introduction/support-matrix/
    bootstrap_node     = string # IP of the control plane used for bootstrap and kubeconfig retrieval
  })
}

variable "nodes" {
  description = "Node Configuration"
  type = map(object({
    machine_type  = string
    update        = optional(bool, false)
    ip            = string
    cidr          = number
    gateway       = string
    cpu           = number
    disk_size     = number
    ram_dedicated = number
    host_node     = string
    vm_id         = number
    datastore_id  = string
  }))
}

variable "import_mode" {
  description = "When true, skips cluster bootstrapping to allow safe VM import into state. Disables: machine config apply, health check, sealed-secrets, CSI plugin."
  type        = bool
  default     = false
}
