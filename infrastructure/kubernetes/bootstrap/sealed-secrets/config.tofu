resource "kubernetes_namespace_v1" "sealed-secrets" {
  metadata {
    name = "sealed-secrets"
  }
}

resource "kubernetes_secret_v1" "sealed-secrets-key" {
  depends_on = [kubernetes_namespace_v1.sealed-secrets]
  type       = "kubernetes.io/tls"

  metadata {
    name      = "sealed-secrets-bootstrap-key"
    namespace = kubernetes_namespace_v1.sealed-secrets.metadata[0].name
    labels = {
      "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
    }
  }

  data = {
    "tls.crt" = var.certificate.cert
    "tls.key" = var.certificate.key
  }
}
