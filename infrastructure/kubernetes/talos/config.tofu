resource "talos_machine_secrets" "this" {
  talos_version = var.cluster.talos_version

  # Never destroy machine secrets — regenerating them breaks all cluster nodes.
  # To intentionally replace: tofu state rm, then tofu apply.
  lifecycle {
    prevent_destroy = true
  }
}

data "talos_client_configuration" "this" {
  count = var.import_mode ? 0 : 1

  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each = var.import_mode ? {} : var.nodes

  cluster_name        = var.cluster.name
  cluster_endpoint    = "https://${var.cluster.endpoint}:6443"
  talos_version       = var.cluster.talos_version
  kubernetes_version  = var.cluster.kubernetes_version
  machine_type        = each.value.machine_type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = each.value.machine_type == "controlplane" ? [
    templatefile("${path.module}/machine-config/control-plane.yaml.tftpl", {
      node_name      = each.value.host_node
      cluster_name   = var.cluster.proxmox_cluster
      cilium_values  = var.cilium.values
      cilium_install = var.cilium.install
    })
    ] : [
    templatefile("${path.module}/machine-config/worker.yaml.tftpl", {
      node_name    = each.value.host_node
      cluster_name = var.cluster.proxmox_cluster
    })
  ]
}

resource "talos_machine_configuration_apply" "this" {
  for_each = var.import_mode ? {} : var.nodes

  depends_on = [proxmox_virtual_environment_vm.this]

  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

resource "talos_machine_bootstrap" "this" {
  count = var.import_mode ? 0 : 1

  depends_on = [talos_machine_configuration_apply.this]

  node                 = var.cluster.bootstrap_node
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_cluster_health" "this" {
  count = var.import_mode ? 0 : 1

  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
  ]

  client_configuration = data.talos_client_configuration.this[0].client_configuration
  control_plane_nodes  = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
  worker_nodes         = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  endpoints            = data.talos_client_configuration.this[0].endpoints
  timeouts = {
    read = "30m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  count = var.import_mode ? 0 : 1

  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this,
  ]

  node                 = var.cluster.bootstrap_node
  endpoint             = var.cluster.endpoint
  client_configuration = talos_machine_secrets.this.client_configuration
  timeouts = {
    read = "1m"
  }
}

# Control plane upgrades run first to preserve etcd quorum before workers are upgraded.
resource "null_resource" "upgrade_controlplanes" {
  for_each = var.import_mode ? {} : {
    for k, v in var.nodes : k => v if v.update && v.machine_type == "controlplane"
  }

  triggers = {
    node_ip         = each.value.ip
    installer_image = coalesce(var.image.installer_image, "none")
    update_flag     = tostring(each.value.update)
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/upgrade-node.sh '${each.value.ip}' '${each.key}' '${var.image.installer_image}' '${path.module}/../../../config/${var.cluster.environment}/talos-config.yaml'"
  }

  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
  ]
}

# Workers only upgrade after all control planes have finished.
resource "null_resource" "upgrade_workers" {
  for_each = var.import_mode ? {} : {
    for k, v in var.nodes : k => v if v.update && v.machine_type == "worker"
  }

  triggers = {
    node_ip         = each.value.ip
    installer_image = coalesce(var.image.installer_image, "none")
    update_flag     = tostring(each.value.update)
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/upgrade-node.sh '${each.value.ip}' '${each.key}' '${var.image.installer_image}' '${path.module}/../../../config/${var.cluster.environment}/talos-config.yaml'"
  }

  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this,
    null_resource.upgrade_controlplanes,
  ]
}
