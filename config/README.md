# config/

Runtime configuration files for each cluster environment. **All files in this directory are gitignored** — they must be created locally after a fresh clone and are never committed to the repository.

---

## Directory structure

```text
config/
└── {env}/                               e.g. prod or dev
    ├── certificates/
    │   ├── sealed-secrets.cert          Pre-generated (INPUT  — must exist before tofu apply)
    │   └── sealed-secrets.key           Pre-generated (INPUT  — must exist before tofu apply)
    ├── talos-config.yaml                Written by tofu apply
    ├── kube-config.yaml                 Written by tofu apply
    ├── talos-machine-config-<node>.yaml Written by tofu apply (one per node)
    └── kcp/                             Optional: KCP control plane files (manual)
```

---

## Files you must create before the first `tofu apply`

### `certificates/sealed-secrets.cert` and `sealed-secrets.key`

These are read by OpenTofu during the **plan** phase (before any resources are created), so they must exist on disk first. The easiest way is to run:

```bash
cd infrastructure/kubernetes
./setup-config.sh prod   # or dev
```

This script is idempotent — it skips generation if the files already exist.

To generate manually:

```bash
mkdir -p config/prod/certificates
cd config/prod/certificates
openssl req -x509 -days 3650 -nodes -newkey rsa:4096 \
  -keyout sealed-secrets.key \
  -out    sealed-secrets.cert \
  -subj   "/CN=sealed-secret/O=sealed-secret"
chmod 600 sealed-secrets.key
```

> **Keep the private key safe.** Anyone with `sealed-secrets.key` can decrypt all sealed secrets in the cluster. The public certificate (`sealed-secrets.cert`) is safe to share and is needed by `kubeseal` to encrypt new secrets.

---

## Files written by `tofu apply` (do not create manually)

| File | Written by |
|------|-----------|
| `talos-config.yaml` | `output.tofu` → `local_file.talos_config` |
| `kube-config.yaml` | `output.tofu` → `local_file.kube_config` |
| `talos-machine-config-<node>.yaml` | `output.tofu` → `local_file.machine_configs` |

These are overwritten on every `tofu apply`. Do not edit them by hand.

---

## Sealing secrets with kubeseal

Once the cluster is running and `kubeseal` is installed, use the pre-generated certificate to seal secrets without needing cluster access:

```bash
kubeseal \
  --format yaml \
  --cert config/prod/certificates/sealed-secrets.cert \
  < my-secret.yaml \
  > my-secret-sealed.yaml
```

---

## Re-creating certificates (e.g. after key rotation)

If you need to rotate the sealed secrets key:

1. Delete the existing cert and key files.
2. Run `./setup-config.sh prod` to generate new ones.
3. Re-run `tofu apply` to update the Kubernetes secret in the cluster.
4. Re-seal all existing secrets using the new certificate.

> **Warning:** Existing sealed secrets encrypted with the old key will no longer be decryptable after rotation unless you keep the old key available in the cluster.
