#!/bin/bash
echo "Generating KCP kubeconfig file"

ENV=$1

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

KCP_EXPORT_PATH="$(pwd)/../config/${ENV}/kcp" 
if [ ! -d "$KCP_EXPORT_PATH" ]; then
    echo "Directory does not exist. Creating: $KCP_EXPORT_PATH"
    mkdir -p "$KCP_EXPORT_PATH"
else
    echo "Directory already exists: $KCP_EXPORT_PATH"
fi

KCP_EXTERNAL_HOSTNAME="$(yq '.externalHostname' ../kubernetes/infra/kcp/kcp-values.yaml)" 
pushd $KCP_EXPORT_PATH > /dev/null 

kubectl get secret kcp-external-admin-kubeconfig-cert -n kcp -o jsonpath="{.data.ca\.crt}" | base64 --decode > ca.crt # Server certificate 
kubectl get secret cluster-admin-client-cert -n kcp -o=jsonpath='{.data.tls\.crt}' | base64 -d > client.crt
kubectl get secret cluster-admin-client-cert -n kcp -o=jsonpath='{.data.tls\.key}' | base64 -d > client.key

kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig config set-cluster base --server https://$KCP_EXTERNAL_HOSTNAME:8443 --certificate-authority=ca.crt
kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig config set-cluster root --server https://$KCP_EXTERNAL_HOSTNAME:8443/clusters/root --certificate-authority=ca.crt
kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig config set-credentials kcp-admin --client-certificate=client.crt --client-key=client.key
kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig config set-context base --cluster=base --user=kcp-admin
kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig config set-context root --cluster=root --user=kcp-admin
kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig config use-context root
kubectl --kubeconfig=$KCP_EXPORT_PATH/admin.kubeconfig workspace

popd > /dev/null

echo "Kubeconfig file created at kcp.kubeconfig"
echo ""
echo "export KUBECONFIG=$KCP_EXPORT_PATH/admin.kubeconfig"
echo ""


