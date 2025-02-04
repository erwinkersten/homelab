## Folder Structure
The following is the folder structure under the `kubernetes` directory:

```
kubernetes/
├── core/        # Contains all core Kubernetes resources bootstrapped with OpenTofu
├── argo-apps/   # Contains the App-of-apps resources to initialize ArgoCD
├── infra/       # Contains all infrastructure resources deployed with ArgoCD
└── apps/        # Contains all application resources deployed with ArgoCD
```

### core
This directory contains all the core Kubernetes resources that are bootstrapped using OpenTofu. These resources include essential services and configurations required for to deploy and provision the infra and app resources. 

For troubleshooting purposes, these resources can also be deployed manually:

```bash
./deploy-core.sh
```

### argo-apps
This directory contains the App-of-apps pattern resources used to initialize and manage ArgoCD. The App-of-apps pattern allows you to manage multiple applications as a single application in ArgoCD. 

To manually trigger the ArgoCD App-of-apps deployment, execute the following command:

```bash
kubectl apply -k kubernetes/argo-apps/
```

### infra
This directory contains all the infrastructure resources that are deployed using ArgoCD. These resources include networking, storage, and other infrastructure components necessary for the applications to run.

### apps
This directory contains all the application resources that are deployed using ArgoCD. Each application has its own directory with the necessary manifests and configurations to deploy and manage the application in the Kubernetes cluster.