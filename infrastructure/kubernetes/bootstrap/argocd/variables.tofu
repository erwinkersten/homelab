variable "argocd" {
  description = "ArgoCD Configuration"
  type = object({
    name      = string
    namespace = string
  })
}