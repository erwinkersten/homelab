
# Configuration files

## Certificates for sealed secrets

Generate asymetric key-pair for each environment [dev|staging|prod]  for sealed secrets

```
cd /config/[dev|staging|prod]/certificates
openssl req -x509 -days 365 -nodes -newkey rsa:4096 -keyout sealed-secrets.key -out sealed-secrets.cert -subj "/CN=sealed-secret/O=sealed-secret"
```

## Example config structure

```
└── config
    ├── README.md
    └── prod
        ├── certificates
        │   ├── sealed-secrets.cert
        │   └── sealed-secrets.key
        ├── kube-config.yaml
        ├── talos-config.yaml
        ├── talos-machine-config-k8-prod-ctrl-00.yaml
        ├── talos-machine-config-k8-prod-ctrl-01.yaml
        ├── talos-machine-config-k8-prod-ctrl-02.yaml
        ├── talos-machine-config-k8-prod-work-00.yaml
        ├── talos-machine-config-k8-prod-work-01.yaml
        └── talos-machine-config-k8-prod-work-02.yaml
```