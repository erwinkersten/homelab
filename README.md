# Home Lab

> 🚧**Work in Progress**🚧: This project is currently under development and is not yet complete. Features, configurations, and documentation may change frequently as work continues. Feedback, and suggestions are welcome, but please be aware that the repository may not yet be fully functional or stable.

This repository offers an easy-to-use and customizable solution for setting up a Kubernetes clusters in a Proxmox VE home lab environment.

Key Features:

- **Automated Provisioning:** Streamlines cluster setup by leveraging OpenTofu to automate the deployment and configuration of Talos Linux nodes.
- **Advanced Network Security and Observability:** Utilizes Cilium to enforce fine-grained network policies and provide robust observability within the Kubernetes cluster.
- **Secure Secret Management:** Protects sensitive Kubernetes secrets with Sealed Secrets, ensuring secure encryption and storage in Git.
- **GitOps-Driven Workflow:** Implements ArgoCD for automated continuous delivery, maintaining alignment between application deployments and the desired state defined in Git repositories.
- **Infrastructure as Code (IaC):** Adheres to IaC best practices, ensuring infrastructure configurations are reproducible, version-controlled, and easy to manage.
- **Hardened Kubernetes Environment:** Delivers a secure and reliable cluster through the integration of GitOps practices, automated provisioning, Cilium network policies, Kyverno Policies and Sealed Secrets.

Here's an improved version of your **Getting Started** section and the **Folder Structure Overview**. The rewrite aims to make it more actionable, readable, and concrete. I’ve also updated or removed vague sections and added clarity to the GitOps deployment part.


## 🚀 Getting Started

This project provides a streamlined and reproducible way to deploy **Talos Kubernetes clusters** on **Proxmox VE** using **OpenTofu** and **GitOps** with **ArgoCD**. 

### ✅ Prerequisites

Make sure the following tools are installed:

- Proxmox VE server(s)
- [OpenTofu](https://opentofu.org/) CLI [`brew install opentofu`]
- [kubectl](https://kubernetes.io/docs/tasks/tools/) CLI [`brew install kubernetes-cli`]
- [k9s](https://k9scli.io/) [`brew install k9s`] (optional but recommended)  
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) [`brew install argocd`] (optional, for GitOps workflows) 

### 🛠️ Setup Instructions

1. **Clone the Repository**

   ```bash
   git clone https://github.com/erwinkersten/homelab.git
   cd homelab/infrastructure/kubernetes
   ```

2. **Prepare Environment Configuration**

   Copy the example configuration and edit to match your setup:

   ```bash
   cp environment.prod.tfvars.example environment.prod.tfvars
   # Or for development:
   cp environment.prod.tfvars.example environment.dev.tfvars
   ```

   Open the file in your editor and customize values like Proxmox IPs, storage settings, and VM specs.

3. **Deploy the Kubernetes Cluster**

   Run the deploy script with your environment name:

   ```bash
   ./tofu-deploy.sh prod
   # or for dev:
   ./tofu-deploy.sh dev
   ```

   This will provision Talos-based K8s nodes on your Proxmox server.

4. **Bootstrap Kubernetes with Core services**
   > ⚠️ Temporary manual step: After the cluster is created, manually bootstrap it with the core Kubernetes configuration and essential operators to prepare the environment.
      
    ```bash
    cd kubernetes/core
    ./deploy-core.sh
    cd ../..
    ```

5. **Bootstrap GitOps with ArgoCD**
    > ⚠️ Temporary manual step: After bootstrapping the cluster, you can bootstrap the GitOps setup using ArgoCD’s App-of-Apps pattern.

   ```bash
   kubectl apply -k kubernetes/argo-apps/
   ```
   This will install ArgoCD and trigger the deployment of your infrastructure and app resources defined in Git.

---

## 📁 Kubernetes Folder Structure Overview

A quick guide to what's where in the Kubernetes deployment setup:

```
kubernetes/
├── core/        # Talos bootstrapping components (CRs, secrets, etc.)
├── argo-apps/   # ArgoCD App-of-Apps configuration
├── infra/       # Cluster-wide infrastructure (e.g. ingress, certs)
└── apps/        # Application workloads and services
```

### `core/`

Contains the base components needed to initialize the Talos cluster.

Manual deployment (if needed):

```bash
./deploy-core.sh
```

### `argo-apps/`

Defines the ArgoCD App-of-Apps hierarchy. This is the entry point for GitOps bootstrapping.

Deploy with:

```bash
kubectl apply -k kubernetes/argo-apps/
```

### `infra/`

This directory contains all the infrastructure resources that are deployed using ArgoCD. These resources include networking, storage, and other infrastructure components necessary for the applications to run.

### `apps/`

This directory contains all the application resources that are deployed using ArgoCD. Each application has its own directory with the necessary manifests and configurations to deploy and manage the application in the Kubernetes cluster.

## Resources

- Proxmox VE: [https://www.proxmox.com/en/](https://www.proxmox.com/en/)
- Talos Linux [https://www.talos.dev/](https://www.talos.dev/)
- OpenTofu: [https://opentofu.org/](https://opentofu.org/)
- Kubernetes: [https://kubernetes.io/](https://kubernetes.io/)
- ArgoCD: [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)
- Cilium: [https://cilium.io/](https://cilium.io/)
- CertManager [https://cert-manager.io/](https://cert-manager.io/)
- Sealed Secrets [https://github.com/bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)