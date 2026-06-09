resource "local_file" "machine_configs" {
  for_each        = var.import_mode ? {} : module.talos.machine_config
  content         = each.value.machine_configuration
  filename        = "../../config/${var.cluster.environment}/talos-machine-config-${each.key}.yaml"
  file_permission = "0600"
}

resource "local_file" "talos_config" {
  count           = var.import_mode ? 0 : 1
  content         = module.talos.client_configuration.talos_config
  filename        = "../../config/${var.cluster.environment}/talos-config.yaml"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  count           = var.import_mode ? 0 : 1
  content         = module.talos.kube_config.kubeconfig_raw
  filename        = "../../config/${var.cluster.environment}/kube-config.yaml"
  file_permission = "0600"
}

resource "local_file" "csi_config" {
  count    = var.import_mode ? 0 : 1
  content  = var.import_mode ? "" : <<-EOF
    clusters:
    - url: "${var.proxmox.endpoint}/api2/json"
      insecure: ${var.proxmox.insecure}
      token_id: "${module.proxmox_csi_plugin[0].token_id}"
      token_secret: "${module.proxmox_csi_plugin[0].token_secret}"
      region: ${var.proxmox.cluster_name}
    EOF
  filename        = "../../config/${var.cluster.environment}/csi-config.yaml"
  file_permission = "0600"
}

output "kube_config" {
  value     = var.import_mode ? null : module.talos.kube_config.kubeconfig_raw
  sensitive = true
}

output "talos_config" {
  value     = var.import_mode ? null : module.talos.client_configuration.talos_config
  sensitive = true
}
