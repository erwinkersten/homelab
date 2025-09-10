locals {
  version = var.image.version
  schematic = var.image.schematic
  datastore = var.image.proxmox_iso_ds
  node_name = var.image.proxmox_node
  image_id = "${talos_image_factory_schematic.this.id}_${local.version}"
  update_version = coalesce(var.image.update_version, var.image.version)
  update_schematic = coalesce(var.image.update_schematic, var.image.schematic)
  update_image_id = "${talos_image_factory_schematic.updated.id}_${local.update_version}"
  
  # Create unique image sets to avoid duplicates
  unique_images = toset([
    for k, v in var.nodes : v.update ? local.update_image_id : local.image_id
  ])
  
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

# Download unique images only
resource "proxmox_virtual_environment_download_file" "unique_images" {
  for_each = local.unique_images

  node_name    = local.node_name
  content_type = "iso"
  datastore_id = local.datastore

  file_name = "talos-${split("_", each.value)[0]}-${split("_", each.value)[1]}-${var.image.platform}-${var.image.arch}.img"

  url = "${var.image.factory_url}/image/${split("_", each.value)[0]}/${split("_", each.value)[1]}/${var.image.platform}-${var.image.arch}.raw.gz"

  decompression_algorithm = "gz"
  overwrite               = false  # Set to false initially
  
  # Add lifecycle to prevent recreation issues
  lifecycle {
    ignore_changes = [
      file_name,
      url
    ]
  }
}

# Create references for each node
locals {
  node_image_refs = {
    for k, v in local.computed_nodes : k => {
      file_id = proxmox_virtual_environment_download_file.unique_images[v.image_id].id
      image_id = v.image_id
    }
  }
}

output "download_urls" {
  value = [for image_id in local.unique_images : "${var.image.factory_url}/image/${split("_", image_id)[0]}/${split("_", image_id)[1]}/${var.image.platform}-${var.image.arch}.raw.gz"]
}

output "node_image_refs" {
  value = local.node_image_refs
}