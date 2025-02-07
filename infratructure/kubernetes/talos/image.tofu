locals {
  version = var.image.version
  schematic = var.image.schematic
  datastore = var.image.proxmox_iso_ds
  node_name = var.image.proxmox_node
  image_id = "${talos_image_factory_schematic.this.id}_${local.version}"
  update_version = coalesce(var.image.update_version, var.image.version)
  update_schematic = coalesce(var.image.update_schematic, var.image.schematic)
  update_image_id = "${talos_image_factory_schematic.updated.id}_${local.update_version}"
  computed_nodes = {
    for k, v in var.nodes : k => merge(v, {
      image_id = v.update ? local.update_image_id : local.image_id
    })
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = local.schematic
}

resource "talos_image_factory_schematic" "updated" {
  schematic = local.update_schematic
}

resource "proxmox_virtual_environment_download_file" "this" {
  # Use the precomputed map; the keys are the same as those of var.nodes (static)
  for_each = local.computed_nodes

  node_name    = each.value.host_node
  content_type = "iso"
  datastore_id = local.datastore

  file_name = "talos-${split("_", each.value.image_id)[0]}-${split("_", each.value.image_id)[1]}-${var.image.platform}-${var.image.arch}.img"

  url = "${var.image.factory_url}/image/${split("_", each.value.image_id)[0]}/${split("_", each.value.image_id)[1]}/${var.image.platform}-${var.image.arch}.raw.gz"

  decompression_algorithm = "gz"
  overwrite               = false 
}