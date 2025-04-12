### Helm Chart CRD Upgrade Issues

**Important**: The Helm chart for `kube-prometheus-stack` may exhibit inconsistent behavior when applying or upgrading Custom Resource Definitions (CRDs). Starting from version **68.4.0**, Helm provides the `crds.upgradeJob.enabled` option specifically to handle CRD upgrades.

If you encounter issues during installation or upgrades related to CRDs, refer to the official documentation:

- [kube-prometheus-stack Helm Chart Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Helm Chart README](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md)


***ISSUE: crds are not installed by the chart at the moment. ***
```
LATEST=$(curl -s https://api.github.com/repos/prometheus-operator/prometheus-operator/releases/latest | jq -cr .tag_name)
curl -sL https://github.com/prometheus-operator/prometheus-operator/releases/download/${LATEST}/bundle.yaml | kubectl create -f -
```


---

### Sealing Secrets with Kubeseal

To securely seal your Kubernetes secrets, execute the following command using `kubeseal`:

```sh
kubeseal --format yaml --controller-namespace sealed-secrets < kubernetes/infra/observability/grafana-admin-secret.yaml_encrypt > kubernetes/infra/observability/grafana-admin-secret.yaml
```

**Input File Example** (for reference only; not included in the repository due to containing sensitive base64-encoded secrets):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin-secret
  namespace: observability
  labels:
    app.kubernetes.io/name: kube-prometheus-stack
data:
  admin-user: "admin"                    # Encoded via: echo -n 'admin' | base64
  admin-password: "admin-password"       # Encoded via: echo -n 'admin-password' | base64
```

Ensure the secret file (`grafana-admin-secret.yaml_encrypt`) contains properly base64-encoded data before sealing.

