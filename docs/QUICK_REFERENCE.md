# IDP Quick Reference Card

## Architecture

```
Developer → NGINX Ingress → Backstage (Portal)
                          ↘ ArgoCD (GitOps)
```

**That's it!** Simple, clean, production-ready.

## URLs (Local)

| Service | URL | Purpose |
|---------|-----|---------|
| Backstage | http://backstage.localhost | Developer portal |
| ArgoCD | http://argocd.localhost | GitOps UI |

## Deployment Commands

```powershell
# First time setup
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy IDP
kubectl apply -f gitops/app-of-apps/bootstrap.yaml

# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
```

## What Each Component Does

### Backstage (The Portal)
- Service catalog (what services exist)
- Software templates (create new services)
- TechDocs (documentation)
- ArgoCD integration (deployment status)
- Kubernetes view (pods, services)

**For**: Application developers

### ArgoCD (GitOps)
- Deploys applications from Git
- Auto-syncs changes
- Shows deployment health
- Manages rollbacks

**For**: Platform engineers & developers

### NGINX Ingress
- Routes traffic to services
- Single entry point

**For**: Infrastructure

## GitOps Structure

```
gitops/
├── app-of-apps/           # Infrastructure bootstrap
│   ├── bootstrap.yaml     # Apply this ONCE manually
│   ├── appprojects.yaml   # RBAC & security
│   └── platform-apps.yaml # Core services
│
└── applications/          # Your applications
    └── my-app.yaml        # Add your apps here
```

## Common Tasks

### Deploy a New App
1. Create `gitops/applications/my-app.yaml`
2. Commit and push to Git
3. ArgoCD auto-syncs

### Check What's Running
```powershell
kubectl get applications -n argocd
```

### View Backstage Logs
```powershell
kubectl logs -n backstage deployment/backstage -f
```

### Access Services Without Ingress
```powershell
# Backstage
kubectl port-forward -n backstage svc/backstage 7007:7007

# ArgoCD  
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

## What Was Removed

❌ CNOE platform container (unnecessary)  
❌ Static landing page (redundant)  
❌ Custom API gateway (Backstage has APIs)  
❌ Multiple portals (Backstage is THE portal)

## Developer Workflow

1. Open Backstage → http://backstage.localhost
2. Browse service catalog
3. Create new service from template
4. View deployment status (ArgoCD integration)
5. Check Kubernetes resources

**Everything in one place!**

## Files You Need to Update

Before deploying, update these files with your Git repository URL:
- `gitops/app-of-apps/bootstrap.yaml`
- `gitops/app-of-apps/platform-apps.yaml`

Replace: `https://github.com/your-org/idp.git`

## Troubleshooting

**Can't access Backstage?**
- Check hosts file has `127.0.0.1 backstage.localhost`
- Check pod is running: `kubectl get pods -n backstage`

**ArgoCD not syncing?**
- Check repository URL is correct
- Check ArgoCD has access to Git repo
- Check `kubectl get applications -n argocd`

**PostgreSQL issues?**
- Check: `kubectl get pods -n backstage | grep postgres`
- View logs: `kubectl logs -n backstage deployment/postgres-backstage`

## Production Checklist

- [ ] Replace .localhost with real domains
- [ ] Enable TLS (cert-manager)
- [ ] Configure OAuth (GitHub/Azure AD)
- [ ] Add monitoring (Prometheus)
- [ ] Setup database backups
- [ ] Configure external secrets
- [ ] Add resource limits
- [ ] Enable high availability

## Support

- Full setup guide: [docs/LOCAL_SETUP.md](LOCAL_SETUP.md)
- Architecture changes: [docs/ARCHITECTURE_CHANGES.md](ARCHITECTURE_CHANGES.md)
- Backstage docs: https://backstage.io
- ArgoCD docs: https://argo-cd.readthedocs.io

---

**Remember**: Backstage is YOUR developer portal. Everything else supports it.
