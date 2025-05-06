#!/bin/bash

# Function to display an error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}


# Check if kubectl is installed
command -v kubectl >/dev/null 2>&1 || error_exit "kubectl is not installed. Please install it and try again."

# Check if jq is installed
command -v jq >/dev/null 2>&1 || error_exit "jq is not installed. Please install it and try again."


# Retrieve the ArgoCD admin password

echo "Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -ojson 2>/dev/null | jq -r '.data.password | @base64d' 2>/dev/null)
if [[ -z "$ARGOCD_PASSWORD" ]]; then
    error_exit "Failed to retrieve the ArgoCD admin password. Ensure the 'argocd-initial-admin-secret' exists in the 'argocd' namespace."
fi

echo "ArgoCD admin password: $ARGOCD_PASSWORD"