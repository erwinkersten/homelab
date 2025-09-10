resource "local_file" "machine_configs" {
  for_each        = var.skip_health_check ? {} : module.talos.machine_config
  content         = each.value.machine_configuration
  filename        = "../../config/${var.cluster.environment}/talos-machine-config-${each.key}.yaml"
  file_permission = "0600"
}

resource "local_file" "talos_config" {
  count           = var.skip_health_check ? 0 : 1
  content         = module.talos.client_configuration.talos_config
  filename        = "../../config/${var.cluster.environment}/talos-config.yaml"
  file_permission = "0600"
}

resource "local_file" "kube_config" {
  count           = var.skip_health_check ? 0 : 1
  content         = module.talos.kube_config.kubeconfig_raw
  filename        = "../../config/${var.cluster.environment}/kube-config.yaml"
  file_permission = "0600"
}

output "kube_config" {
  value     = var.skip_health_check ? null : module.talos.kube_config.kubeconfig_raw
  sensitive = true
}

output "talos_config" {
  value     = var.skip_health_check ? null : module.talos.client_configuration.talos_config
  sensitive = true
}
