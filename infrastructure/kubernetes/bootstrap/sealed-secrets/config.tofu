# Namespace and bootstrap key are now created by deploy-core.sh via kubectl,
# before the sealed-secrets controller is deployed. This avoids a dependency on
# OpenTofu's Kubernetes provider during the turbulent cluster bootstrap window,
# where transient TLS timeouts caused namespace creation to fail.
