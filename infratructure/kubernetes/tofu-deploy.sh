#!/bin/bash

ENV=$1

if [[ -z "$ENV" || ! "$ENV" =~ ^(dev|prod)$ ]]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

tofu workspace select $ENV || tofu workspace new $ENV
tofu apply -var-file="environment.${ENV}.tfvars" 
export KUBECONFIG="${PWD}/../../config/${ENV}/kube-config.yaml" 
kubectl get nodes
echo "Use the following command to use the kubeconfig: export KUBECONFIG=\"${PWD}/../../config/${ENV}/kube-config.yaml\""