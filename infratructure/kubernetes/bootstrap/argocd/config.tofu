resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd.namespace
  }
}

resource "helm_release" "argocd" {
  name       = var.argocd.name
  namespace  = var.argocd.namespace
  create_namespace = false
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  # values     = [file("values/argocd.yaml")]
}
