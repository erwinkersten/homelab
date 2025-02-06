#!/bin/bash
kubectl apply -k crds
kubectl apply -k controllers/kubelet-serving-cert-approver
kustomize build --enable-helm network/cilium | kubectl apply -f -
kustomize build --enable-helm network/gateway | kubectl apply -f -
kustomize build --enable-helm controllers/argocd | kubectl apply -f -
kustomize build --enable-helm controllers/cert-manager | kubectl apply -f -   
kustomize build --enable-helm controllers/sealed-secrets | kubectl apply -f -
kustomize build --enable-helm storage/csi-proxmox | kubectl apply -f -