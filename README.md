# Home Lab

> 🚧**Work in Progress**🚧: This project is currently under development and is not yet complete. Features, configurations, and documentation may change frequently as work continues. Feedback, and suggestions are welcome, but please be aware that the repository may not yet be fully functional or stable.

This repository offers an easy-to-use and customizable solution for setting up a Kubernetes clusters in a Proxmox VE home lab environment.

Key Features:

- **Automated Provisioning:** Streamlines cluster setup by leveraging OpenTofu to automate the deployment and configuration of Talos Linux nodes.
- **Advanced Network Security and Observability:** Utilizes Cilium to enforce fine-grained network policies and provide robust observability within the Kubernetes cluster.
- **Secure Secret Management:** Protects sensitive Kubernetes secrets with Sealed Secrets, ensuring secure encryption and storage in Git.
- **GitOps-Driven Workflow:** Implements ArgoCD for automated continuous delivery, maintaining alignment between application deployments and the desired state defined in Git repositories.
- **Infrastructure as Code (IaC):** Adheres to IaC best practices, ensuring infrastructure configurations are reproducible, version-controlled, and easy to manage.
- **Hardened Kubernetes Environment:** Delivers a secure and reliable cluster through the integration of GitOps practices, automated provisioning, Cilium network policies, and Sealed Secrets.

## Prerequisites

- todo

## Getting Started

- todo

## Resources

- Proxmox VE: [https://www.proxmox.com/en/](https://www.proxmox.com/en/)
- Talos Linux [https://www.talos.dev/](https://www.talos.dev/)
- OpenTofu: [https://opentofu.org/](https://opentofu.org/)
- Kubernetes: [https://kubernetes.io/](https://kubernetes.io/)
- Cilium: [https://cilium.io/](https://cilium.io/)
- Sealed Secrets [https://github.com/bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)