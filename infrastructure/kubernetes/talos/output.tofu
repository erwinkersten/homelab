output "machine_config" {
  value = var.skip_health_check ? {} : data.talos_machine_configuration.this
}

output "client_configuration" {
  value     = var.skip_health_check ? null : data.talos_client_configuration.this[0]
  sensitive = true
}

output "kube_config" {
  #value     = data.talos_cluster_kubeconfig.this
  value = var.skip_health_check ? null : talos_cluster_kubeconfig.this[0]
  sensitive = true
}
