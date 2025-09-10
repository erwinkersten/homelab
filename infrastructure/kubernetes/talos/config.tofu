resource "talos_machine_secrets" "this" {
  count = var.skip_health_check ? 0 : 1
  
  talos_version = var.cluster.talos_version
}

data "talos_client_configuration" "this" {
  count = var.skip_health_check ? 0 : 1
  
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this[0].client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each = var.skip_health_check ? {} : var.nodes
  
  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${var.cluster.endpoint}:6443"
  talos_version    = var.cluster.talos_version
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this[0].machine_secrets
  config_patches   = each.value.machine_type == "controlplane" ? [
    templatefile("${path.module}/machine-config/control-plane.yaml.tftpl", {
      hostname       = each.key
      node_name      = each.value.host_node
      cluster_name   = var.cluster.proxmox_cluster
      cilium_values  = var.cilium.values
      cilium_install = var.cilium.install
    })
  ] : [
    templatefile("${path.module}/machine-config/worker.yaml.tftpl", {
      hostname     = each.key
      node_name    = each.value.host_node
      cluster_name = var.cluster.proxmox_cluster
    })
  ]
}

resource "talos_machine_configuration_apply" "this" {
  # Skip configuration application during import
  for_each = var.skip_health_check ? {} : var.nodes
  
  depends_on = [proxmox_virtual_environment_vm.this]
  
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this[0].client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

# Node upgrade resource using Talos upgrade API
resource "null_resource" "talos_upgrade" {
  for_each = var.skip_health_check ? {} : { for k, v in var.nodes : k => v if v.update }
  
  triggers = {
    node_ip        = each.value.ip
    update_version = var.image.update_version
    update_flag    = each.value.update
    # Force upgrade when image changes
    update_image_id = local.update_image_id
  }
  
  provisioner "local-exec" {
    command = "${path.module}/scripts/upgrade-node.sh '${each.value.ip}' '${each.key}' '${var.image.update_version}' '${split("_", local.update_image_id)[0]}' '${path.module}/../../../config/${var.cluster.environment}/talos-config.yaml'"
  }
  
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]
}

resource "talos_machine_bootstrap" "this" {
  # Skip bootstrap during import
  count = var.skip_health_check ? 0 : 1
  
  depends_on = [talos_machine_configuration_apply.this]
  
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][2]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this[0].client_configuration
}

data "talos_cluster_health" "this" {
  count = var.skip_health_check ? 0 : 1
  
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]
  
  client_configuration = data.talos_client_configuration.this[0].client_configuration
  control_plane_nodes  = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
  worker_nodes         = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  endpoints            = data.talos_client_configuration.this[0].endpoints
  timeouts = {
    read = "10m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  count = var.skip_health_check ? 0 : 1
  
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][2]
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this[0].client_configuration
  timeouts = {
    read = "1m"
  }
}
