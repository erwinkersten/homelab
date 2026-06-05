variable "proxmox" {
  description = "Proxmox connection configuration"
  type = object({
    endpoint = string
    username = string
    password = string
    insecure = bool
  })
  sensitive = true
}

variable "images" {
  description = <<-EOT
    Talos images to download to Proxmox. The map key is a stable label (e.g. "v1-9-1").
    Add a new entry for each new version; keep the old one until all nodes have upgraded.
    Remove old entries only after the upgrade is complete to clean up Proxmox storage.
  EOT
  type = map(object({
    version        = string
    schematic_file = optional(string, "../talos/image/schematic.yaml")
    proxmox_nodes  = list(string)
    proxmox_iso_ds = optional(string, "local")
    platform       = optional(string, "nocloud")
    arch           = optional(string, "amd64")
    factory_url    = optional(string, "https://factory.talos.dev")
  }))
}
