# Home Lab

> 🚧**Work in Progress**🚧: This project is currently under development and is not yet complete. Features, configurations, and documentation may change frequently as work continues. Feedback and suggestions are welcome, but please be aware that the repository may not yet be fully functional or stable.

This repository offers an easy-to-use and customizable solution for setting up a Kubernetes cluster in a Proxmox VE home lab environment.

Key Features:

- **Automated Provisioning:** Streamlines cluster setup by leveraging OpenTofu to automate the deployment and configuration of Talos Linux nodes.
- **Advanced Network Security and Observability:** Utilizes Cilium to enforce fine-grained network policies and provide robust observability within the Kubernetes cluster.
- **Secure Secret Management:** Protects sensitive Kubernetes secrets with Sealed Secrets, ensuring secure encryption and storage in Git.
- **GitOps-Driven Workflow:** Implements ArgoCD for automated continuous delivery, maintaining alignment between application deployments and the desired state defined in Git repositories.
- **Infrastructure as Code (IaC):** Adheres to IaC best practices, ensuring infrastructure configurations are reproducible, version-controlled, and easy to manage.
- **Hardened Kubernetes Environment:** Delivers a secure and reliable cluster through the integration of GitOps practices, automated provisioning, Cilium network policies, Kyverno Policies and Sealed Secrets.

## 🚀 Getting Started

This project provides a streamlined and reproducible way to deploy **Talos Kubernetes clusters** on **Proxmox VE** using **OpenTofu** and **GitOps** with **ArgoCD**.

### ✅ Prerequisites

Make sure the following tools are installed:

- Proxmox VE server(s)
- [OpenTofu](https://opentofu.org/) CLI [`brew install opentofu`]
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl/) CLI [`brew install siderolabs/tap/talosctl`]
- [kubectl](https://kubernetes.io/docs/tasks/tools/) CLI [`brew install kubernetes-cli`]
- [k9s](https://k9scli.io/) [`brew install k9s`] (optional but recommended)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) [`brew install argocd`] (optional, for GitOps workflows)

### 🛠️ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/erwinkersten/homelab.git
cd homelab/infrastructure/kubernetes
```

### 2. Choose Talos and Kubernetes Versions

Every Talos release supports a specific set of Kubernetes versions. Setting a mismatched `kubernetes_version` in `environment.prod.tfvars` will cause the machine config apply to fail.

Check the official support matrix before filling in the versions:
[https://www.talos.dev/latest/introduction/support-matrix/](https://www.talos.dev/latest/introduction/support-matrix/)

Quick reference for recent Talos releases:

| Talos version | Supported Kubernetes versions |
|---------------|-------------------------------|
| v1.9.x        | 1.29, 1.30, 1.31              |
| v1.10.x       | 1.30, 1.31, 1.32              |
| v1.11.x       | 1.31, 1.32, 1.33              |
| v1.12.x       | 1.33, 1.34, 1.35              |
| v1.13.x       | 1.34, 1.35, 1.36              |

> Always verify against the official matrix — the table above may lag behind the latest releases.

Set both values in `environment.prod.tfvars`:

```hcl
cluster = {
  talos_version      = "v1.12.8"  # must match images.prod.tfvars
  kubernetes_version = "1.35.4"   # must be in the supported range above
  ...
}
```

### 3. Prepare Configuration Files

Copy and edit the environment and image configuration files:

```bash
cp environment.prod.tfvars.example environment.prod.tfvars
cp images/images.tfvars.example images.prod.tfvars
```

Edit both files to match your Proxmox setup, node IPs, storage names, Talos version, and Kubernetes version.

### 4. Generate the Config Directory and Sealed Secrets Certificates

The `config/{env}/` directory holds runtime files (kubeconfig, talos config, certificates). It is gitignored and must be set up after every fresh clone. Run:

```bash
./setup-config.sh prod
```

This creates `config/prod/certificates/` and generates the RSA key pair used by Sealed Secrets. The script is idempotent — it skips generation if the certificates already exist.

> The certificates are read by OpenTofu during the **plan** phase, so this step must complete before running `tofu-deploy.sh`. `tofu-deploy.sh` calls `setup-config.sh` automatically, but you can also run it standalone.

See [config/README.md](config/README.md) for a full description of what lives in the config directory and how to seal secrets with `kubeseal`.

### 5. Configure and Seal Secrets

Each secret has a corresponding `*.yaml_encrypt.example` file committed alongside it. Copy each example to a `_encrypt` file (gitignored) and fill in your real values:

```bash
# Example for the Cloudflare API token:
cp kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml_encrypt.example \
   kubernetes/core/controllers/cert-manager/cloudflare-api-token-sealed.yaml_encrypt
```

Edit each `_encrypt` file and replace the `<INSERT: ...>` placeholders with the real secret values.

**Seal the secrets** (requires a running cluster with Sealed Secrets installed):

```bash
export KUBECONFIG="$(pwd)/config/prod/kube-config.yaml"
cd hack && ./generate-sealed-secrets.sh
```

The sealed output files can be committed to git — they are encrypted with the cluster's public key.

> Re-run `generate-sealed-secrets.sh` any time you change a secret value or after rotating the Sealed Secrets keypair.

### 7. Download the Talos Image to Proxmox

Image management is decoupled from cluster provisioning. Run this script once per new Talos version — it uploads the image to Proxmox and only re-downloads if the version is new:

```bash
./tofu-images.sh prod
```

The script prints the `file_id` and `installer_image` values for each image. Copy the `file_id` into `environment.prod.tfvars` under the `image` block:

```hcl
image = {
  file_id = "data:iso/talos-<schematic-id>-v1.12.8-nocloud-amd64.img"
}
```

### 8. Deploy the Cluster and Core Services

```bash
./tofu-deploy.sh prod
```

This single command does everything in sequence:

1. Provisions Talos VMs on Proxmox and bootstraps the Kubernetes cluster
2. Installs the initial Cilium CNI (needed for the cluster health check to pass)
3. Creates Sealed Secrets bootstrap keys and Proxmox CSI credentials in Kubernetes
4. Runs `kubernetes/core/deploy-core.sh` which installs the full component stack:
   - Gateway API CRDs
   - Cilium (full config with L2 announcements and IP pool)
   - Gateway API resources
   - ArgoCD
   - Cert-manager
   - Sealed Secrets controller
   - Proxmox CSI plugin

### 9. Activate GitOps

> ⚠️ One-time manual step: after the cluster is ready, hand control to ArgoCD's App-of-Apps pattern.

```bash
export KUBECONFIG="$(pwd)/../../config/prod/kube-config.yaml"
kubectl apply -k kubernetes/argo-apps/
```

From this point ArgoCD manages all infrastructure and application deployments from Git. The `deploy-core.sh` step is only needed on a fresh cluster — on subsequent changes, GitOps handles reconciliation.

---

## 🔄 Upgrading Talos

Upgrades are handled node-by-node using the Talos upgrade API. Control plane nodes are always upgraded before workers to preserve etcd quorum.

### Finding available versions

- **GitHub releases** — full changelog and release notes:
  [https://github.com/siderolabs/talos/releases](https://github.com/siderolabs/talos/releases)
- **Talos Image Factory** — browse versions, select system extensions, and preview the schematic ID that will be generated from your `talos/image/schematic.yaml`:
  [https://factory.talos.dev](https://factory.talos.dev)

The schematic ID is derived automatically from `talos/image/schematic.yaml` when you run `tofu-images.sh`. If you change the extensions in that file, a new schematic ID is computed and a new image is downloaded on the next run.

### 1. Add the new version to `images.prod.tfvars`

```hcl
images = {
  "v1-9-1" = {           # keep the old version until all nodes are upgraded
    version        = "v1.12.8"
    proxmox_nodes  = ["pve-01"]
    proxmox_iso_ds = "data"
  }
  "v1-9-3" = {           # add the target version
    version        = "v1.13.3"
    proxmox_nodes  = ["pve-01"]
    proxmox_iso_ds = "data"
  }
}
```

### 2. Download the new image to Proxmox

```bash
./tofu-images.sh prod
```

Copy the printed `installer_image` and the new `file_id` into `environment.prod.tfvars`:

```hcl
image = {
  file_id         = "data:iso/talos-<schematic-id>-v1.9.1-nocloud-amd64.img"  # existing image (unchanged)
  update_file_id  = "data:iso/talos-<schematic-id>-v1.9.3-nocloud-amd64.img"  # new image
  installer_image = "factory.talos.dev/installer/<schematic-id>:v1.9.3"
}
```

### 3. Mark nodes for upgrade and apply

Set `update = true` on the nodes you want to upgrade in `environment.prod.tfvars`, then apply:

```bash
./tofu-deploy.sh prod
```

Control planes upgrade first; workers only start after all control planes have completed.

### 4. Clean up after upgrade

Once all nodes are on the new version, remove the old image entry from `images.prod.tfvars`, unset `update_file_id` and `installer_image`, and set `update = false` on all nodes. Then run:

```bash
./tofu-images.sh prod    # removes the old image from Proxmox
./tofu-deploy.sh prod    # clears the update triggers
```

---

## 🗑️ Destroying the Cluster

```bash
./tofu-destroy.sh prod
```

The script will ask whether to override the `prevent_destroy` guard on VMs. Answer **yes** to proceed with a full teardown. The override is automatically removed after a successful destroy.

---

## 📁 Infrastructure Folder Structure

```text
infrastructure/kubernetes/
├── images/                   # Talos image download module (independent state)
│   ├── main.tofu
│   ├── variables.tofu
│   ├── outputs.tofu
│   └── images.tfvars.example
├── talos/                    # Talos cluster provisioning module
│   ├── image.tofu            # Node-to-image mapping
│   ├── virtual_machines.tofu # Proxmox VM resources
│   ├── config.tofu           # Machine config, bootstrap, upgrades
│   ├── machine-config/       # Control plane and worker config templates
│   ├── inline-manifests/     # Cilium installation manifests
│   └── scripts/
│       └── upgrade-node.sh   # Called by OpenTofu during node upgrades
├── bootstrap/
│   ├── sealed-secrets/       # Pre-generated encryption keys
│   ├── proxmox-csi-plugin/   # Proxmox CSI role, user, token, and K8s secret
│   └── argocd/               # ArgoCD Helm release
├── tofu-images.sh            # Download Talos images to Proxmox
├── tofu-deploy.sh            # Create or update the cluster
├── tofu-destroy.sh           # Destroy the cluster
└── tofu-import-skip-health.sh # Import existing VMs into Terraform state
```

## 📁 Kubernetes Folder Structure

```text
kubernetes/
├── core/        # Talos bootstrapping components (CRs, secrets, etc.)
├── argo-apps/   # ArgoCD App-of-Apps configuration
├── infra/       # Cluster-wide infrastructure (e.g. ingress, certs)
└── apps/        # Application workloads and services
```

### `core/`

Contains the base components needed to initialize the Talos cluster.

### `argo-apps/`

Defines the ArgoCD App-of-Apps hierarchy. Entry point for GitOps bootstrapping.

### `infra/`

Infrastructure resources deployed via ArgoCD: networking, storage, and other cluster-wide components.

### `apps/`

Application workloads deployed via ArgoCD. Each application has its own directory with manifests and configuration.

---

## Resources

- Proxmox VE: [https://www.proxmox.com/en/](https://www.proxmox.com/en/)
- Talos Linux: [https://www.talos.dev/](https://www.talos.dev/)
- OpenTofu: [https://opentofu.org/](https://opentofu.org/)
- Kubernetes: [https://kubernetes.io/](https://kubernetes.io/)
- ArgoCD: [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)
- Cilium: [https://cilium.io/](https://cilium.io/)
- CertManager: [https://cert-manager.io/](https://cert-manager.io/)
- Sealed Secrets: [https://github.com/bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)
