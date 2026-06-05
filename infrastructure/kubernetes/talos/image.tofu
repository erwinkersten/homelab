locals {
  node_image_refs = {
    for k, v in var.nodes : k => {
      file_id = v.update ? coalesce(var.image.update_file_id, var.image.file_id) : var.image.file_id
    }
  }
}

output "node_image_refs" {
  value = local.node_image_refs
}
