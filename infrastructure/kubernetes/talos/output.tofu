output "machine_config" {
  value = var.import_mode ? {} : data.talos_machine_configuration.this
}

output "client_configuration" {
  value     = var.import_mode ? null : data.talos_client_configuration.this[0]
  sensitive = true
}

output "kube_config" {
  value     = var.import_mode ? null : talos_cluster_kubeconfig.this[0]
  sensitive = true
}
