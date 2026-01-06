# GitOps Applications

This directory contains ArgoCD Application definitions for the platform.

## Structure

- `bootstrap.yaml` - Root application that deploys all other applications (App of Apps pattern)
- `platform-apps.yaml` - Core platform infrastructure applications
- `appprojects.yaml` - ArgoCD project definitions for RBAC and multi-tenancy

## Usage

### Initial Bootstrap

```bash
# Apply the root application
kubectl apply -f bootstrap.yaml

# Wait for ArgoCD to sync all applications
kubectl get applications -n argocd -w
```

### Adding New Applications

1. Create an Application manifest in this directory
2. Reference it in `platform-apps.yaml` or create a new file
3. Commit and push - ArgoCD will automatically sync

## Application Organization

- **Platform Apps** - Infrastructure and platform services
- **Development Apps** - Developer-facing tools and services
- **Application Apps** - User applications per environment

## Sync Policies

- **Automated Sync** - Enabled for most applications
- **Self-Heal** - Enabled to detect and fix drift
- **Prune** - Enabled to remove deleted resources (except namespaces)
