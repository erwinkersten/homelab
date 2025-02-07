locals {
  version = var.image.version
  schematic = var.image.schematic
  datastore = var.image.proxmox_iso_ds
  node_name = var.image.proxmox_node
  image_id = "${talos_image_factory_schematic.this.id}_${local.version}"
  update_version = coalesce(var.image.update_version, var.image.version)
  update_schematic = coalesce(var.image.update_schematic, var.image.schematic)
  update_image_id = "${talos_image_factory_schematic.updated.id}_${local.update_version}"
}

resource "talos_image_factory_schematic" "this" {
  schematic = local.schematic
}

resource "talos_image_factory_schematic" "updated" {
  schematic = local.update_schematic
}

resource "proxmox_virtual_environment_download_file" "this" {
  content_type            = "iso"
  datastore_id            = local.datastore
  node_name               = local.node_name
  file_name               = "talos-${var.node.update ? local.update_image_id : local.image_id}-nocloud-amd64.img"
  url                     = "${var.image.factory_url}/image/${var.node.update ? local.update_image_id : local.image_id}/nocloud-amd64.raw.gz"
  # file_name               = "talos-${local.version}-nocloud-amd64.img"
  # url                     = "https://factory.talos.dev/image/787b79bb847a07ebb9ae37396d015617266b1cef861107eaec85968ad7b40618/${local.version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}
