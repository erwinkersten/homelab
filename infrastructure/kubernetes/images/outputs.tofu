output "images" {
  description = <<-EOT
    Per-image outputs keyed by the label you defined in images.tfvars.
    Copy the relevant values into your environment.*.tfvars:
      image.file_id        <- images["<label>"].file_ids["<proxmox_node>"]
      image.installer_image <- images["<label>"].installer_image  (used for upgrades)
  EOT
  value = {
    for label, img in var.images : label => {
      file_ids = {
        for node in img.proxmox_nodes :
        node => proxmox_virtual_environment_download_file.this["${label}_${node}"].id
      }
      installer_image = "factory.talos.dev/installer/${talos_image_factory_schematic.this[label].id}:${img.version}"
    }
  }
}
