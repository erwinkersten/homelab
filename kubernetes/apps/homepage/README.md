
# Homepage ArgoCD Widget

Documentation:  https://gethomepage.dev/widgets/services/argocd/

In the ArgoCD [Helm Value file](../../core/controllers/argocd/values.yaml) a readonly user is added based on these values: 

```
configs:
  cm:
    accounts.readonly: apiKey
  rbac:
    policy.csv: "g, readonly, role:readonly"
```


### 1. Retrieve ArgoCD Admin Credentials
Run the following command to get the initial ArgoCD admin password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -ojson | jq -r '.data.password | @base64d'
```

### 2. Login to ArgoCD
Access the ArgoCD UI and log in using the retrieved credentials.

### 3. Generate an API Token for the `readonly` Account
Navigate to the following URL `https://argocd.local.erwinkersten.com/settings/accounts/readonly` to generate an API token for the `readonly` account 

Copy the generated token.

### 4. Add the API Token to `homepage-secret.yaml_encrypt`
Update the `homepage-secret.yaml_encrypt` file with the new token.

### 5. Seal the Secrets
Run the following command to seal the secrets using `kubeseal`:

```sh
kubeseal --format yaml  --controller-namespace sealed-secrets  < kubernetes/apps/homepage/homepage-secret.yaml_encrypt  > kubernetes/apps/homepage/homepage-secret.yaml
```