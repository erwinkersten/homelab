echo "Regenerating sealed secrets"

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal is not installed or not in PATH"
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

kubeseal --format yaml --controller-namespace sealed-secrets < kubernetes/apps/homepage/homepage-secret.yaml_encrypt  > kubernetes/apps/homepage/homepage-secret.yaml
kubeseal --format yaml --controller-namespace sealed-secrets < kubernetes/infra/observability/grafana-admin-secret.yaml_encrypt > kubernetes/infra/observability/grafana-admin-secret.yaml
