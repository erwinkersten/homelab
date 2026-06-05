resource "talos_image_factory_schematic" "this" {
  for_each  = var.images
  schematic = file("${path.module}/${each.value.schematic_file}")
}

locals {
  # Cartesian product of image labels × proxmox nodes
  downloads = merge([
    for label, img in var.images : {
      for node in img.proxmox_nodes :
      "${label}_${node}" => {
        label        = label
        node         = node
        version      = img.version
        schematic_id = talos_image_factory_schematic.this[label].id
        iso_ds       = img.proxmox_iso_ds
        platform     = img.platform
        arch         = img.arch
        factory_url  = img.factory_url
      }
    }
  ]...)
}

resource "proxmox_virtual_environment_download_file" "this" {
  for_each = local.downloads

  node_name    = each.value.node
  content_type = "iso"
  datastore_id = each.value.iso_ds

  file_name = "talos-${each.value.schematic_id}-${each.value.version}-${each.value.platform}-${each.value.arch}.img"
  url       = "${each.value.factory_url}/image/${each.value.schematic_id}/${each.value.version}/${each.value.platform}-${each.value.arch}.raw.gz"

  decompression_algorithm = "gz"
  overwrite               = false
}
