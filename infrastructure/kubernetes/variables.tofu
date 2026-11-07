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

    # Talos version the nodes run. Bump it after every Talos upgrade (talos-upgrade.sh
    # prints when). It needs a matching image entry in images.<env>.tfvars, and
    # image.file_id should point at that image.
    talos_version = string

    # Talos version whose machine configuration format OpenTofu generates (the "version
    # contract" of the Talos provider). Nodes accept configuration in an older format, so
    # this stays pinned while talos_version moves up. Changing it changes the generated
    # configuration of every node: from v1.14 on it switches to a new multi-document
    # format that the templates in talos/machine-config/ are not migrated to yet.
    # It must not be newer than talos_version.
    talos_config_version = string

    kubernetes_version = string # must be supported by talos_version — see https://docs.siderolabs.com/talos/latest/getting-started/support-matrix
    bootstrap_node     = string # IP of the control plane used for bootstrap and kubeconfig retrieval
  })

  validation {
    condition = alltrue([
      for v in [var.cluster.talos_version, var.cluster.talos_config_version] :
      can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", v))
    ])
    error_message = "cluster.talos_version and cluster.talos_config_version must look like v1.14.5."
  }

  validation {
    condition = (
      tonumber(split(".", trimprefix(var.cluster.talos_config_version, "v"))[0]) * 1000 +
      tonumber(split(".", trimprefix(var.cluster.talos_config_version, "v"))[1])
      <=
      tonumber(split(".", trimprefix(var.cluster.talos_version, "v"))[0]) * 1000 +
      tonumber(split(".", trimprefix(var.cluster.talos_version, "v"))[1])
    )
    error_message = "cluster.talos_config_version must not be a newer minor version than cluster.talos_version: nodes cannot read a configuration format newer than their own version."
  }
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
