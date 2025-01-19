

Get ArgoCD default admin password when Admin user is enabled in HelmChart (`config.cm.admin.enabled: true`).

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```