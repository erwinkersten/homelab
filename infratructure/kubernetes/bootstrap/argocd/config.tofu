# resource "kubernetes_namespace" "argocd" {
#   metadata {
#     name = var.argocd.namespace
#   }
# }

resource "helm_release" "argocd" {
  name       = var.argocd.name
  namespace  = var.argocd.namespace
  create_namespace = true
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  values     = [file("${path.module}/../../../../kubernetes/infra/controllers/argocd/values.yaml")]
}