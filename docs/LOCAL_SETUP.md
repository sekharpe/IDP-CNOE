# Local Development Setup - Internal Developer Portal

## Architecture Overview

This IDP consists of **3 core components**:

```
┌─────────────────────────────────────────────────────┐
│                   Developers                         │
└───────────────────────┬─────────────────────────────┘
                        │
                        ↓
┌─────────────────────────────────────────────────────┐
│          NGINX Ingress Controller                   │
│     (Routes traffic to services)                     │
└────┬────────────────────────────────────┬───────────┘
     │                                    │
     ↓                                    ↓
┌────────────────┐              ┌─────────────────┐
│   Backstage    │←─────────────│    ArgoCD       │
│ (Dev Portal)   │  Integrates  │ (GitOps Engine) │
│ Port: 7007     │    with      │ Port: 80        │
└────────────────┘              └─────────────────┘
```

### What Was Removed

✅ **REMOVED**: CNOE platform container (unnecessary abstraction layer)
✅ **SIMPLIFIED**: Direct access to Backstage and ArgoCD
✅ **STREAMLINED**: Standard IDP architecture without redundant layers

## Prerequisites

1. **Docker Desktop** with Kubernetes enabled
   - Settings → Kubernetes → Enable Kubernetes
   - Wait for Kubernetes to start

2. **kubectl** CLI installed
   ```powershell
   kubectl version --client
   ```

3. **Git repository** (for GitOps)
   - Fork or clone this repository
   - Update repo URLs in the manifests

## Quick Start

### Step 1: Configure Local DNS

Add these entries to your hosts file:

**Windows**: `C:\Windows\System32\drivers\etc\hosts`
**Mac/Linux**: `/etc/hosts`

```
127.0.0.1 backstage.localhost
127.0.0.1 argocd.localhost
```

### Step 2: Update Repository URLs

Update the Git repository URL in these files:
- [gitops/app-of-apps/bootstrap.yaml](gitops/app-of-apps/bootstrap.yaml)
- [gitops/app-of-apps/platform-apps.yaml](gitops/app-of-apps/platform-apps.yaml)

Replace `https://github.com/your-org/idp.git` with your actual repository URL.

### Step 3: Deploy ArgoCD (Bootstrap)

```powershell
# Install ArgoCD manually (first time only)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 4: Deploy the IDP (App-of-Apps Pattern)

```powershell
# Apply the bootstrap application (this deploys everything else)
kubectl apply -f gitops/app-of-apps/bootstrap.yaml

# Watch the deployments
kubectl get applications -n argocd --watch
```

### Step 5: Access the Services

**ArgoCD UI**: http://argocd.localhost
- Username: `admin`
- Password: (from Step 3)

**Backstage Portal**: http://backstage.localhost
- Guest authentication enabled for development

## Architecture Components

### 1. **Backstage** - The Developer Portal

**URL**: http://backstage.localhost

**Features**:
- Service catalog
- Software templates (scaffolding)
- TechDocs (documentation)
- ArgoCD integration (deployment status)
- Kubernetes plugin (view pods, services)

**Database**: PostgreSQL (deployed in cluster)

**Configuration**: [infrastructure/kubernetes/backstage/app-config.yaml](infrastructure/kubernetes/backstage/app-config.yaml)

### 2. **ArgoCD** - GitOps Continuous Delivery

**URL**: http://argocd.localhost

**Features**:
- GitOps-based deployment
- Automatic sync from Git
- Application health monitoring
- Rollback capabilities

**App-of-Apps Pattern**:
- `bootstrap.yaml` → Creates root-app
- `appprojects.yaml` → Defines access control
- `platform-apps.yaml` → Deploys infrastructure

### 3. **NGINX Ingress Controller**

**Purpose**: Routes external traffic to services

**Routes**:
- `backstage.localhost` → Backstage service (port 7007)
- `argocd.localhost` → ArgoCD service (port 80)

## Directory Structure

```
idp/
├── gitops/
│   ├── app-of-apps/               # GitOps bootstrap
│   │   ├── bootstrap.yaml         # Root application (apply this manually)
│   │   ├── appprojects.yaml       # ArgoCD projects & RBAC
│   │   └── platform-apps.yaml     # Core infrastructure apps
│   │
│   ├── applications/              # Application definitions
│   │   ├── sample-app.yaml        # Example application
│   │   └── cnoe-platform.yaml     # DISABLED (not needed)
│   │
│   └── overlays/                  # Kustomize overlays (dev/staging/prod)
│
├── infrastructure/
│   ├── kubernetes/
│   │   ├── argocd/                # ArgoCD configuration
│   │   ├── backstage/             # Backstage deployment
│   │   ├── ingress/               # NGINX Ingress
│   │   ├── namespaces/            # Namespace definitions
│   │   └── cnoe-platform/         # DISABLED (not deployed)
│   │
│   └── terraform/                 # Cloud infrastructure (Azure)
│
├── backstage/
│   └── templates/                 # Software templates
│
└── docs/                          # Documentation
```

## What Gets Deployed

### By Bootstrap (Root App)

1. **AppProjects** - Security boundaries for applications
2. **Platform Apps** - Deploys all infrastructure

### By Platform Apps

1. **ArgoCD** - Self-manages itself
2. **NGINX Ingress** - Traffic routing
3. **Namespaces** - Logical boundaries
4. **Backstage** - Developer portal

### By Applications Folder

Individual applications (e.g., sample-app) can be added here and referenced.

## Common Operations

### View All Applications

```powershell
kubectl get applications -n argocd
```

### Sync an Application

```powershell
# Via UI: http://argocd.localhost
# Or via CLI:
kubectl patch application backstage -n argocd --type merge -p '{"metadata": {"annotations": {"argocd.argoproj.io/refresh": "hard"}}}'
```

### Check Backstage Logs

```powershell
kubectl logs -n backstage deployment/backstage -f
```

### Access Backstage Database

```powershell
kubectl exec -it -n backstage deployment/postgres-backstage -- psql -U backstage
```

### Port Forward (Alternative to Ingress)

```powershell
# Backstage
kubectl port-forward -n backstage svc/backstage 7007:7007

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

## Developer Workflow

### For Application Developers

1. **Access Backstage**: http://backstage.localhost
2. **Browse Catalog**: View existing services and APIs
3. **Create New Service**: Use software templates to scaffold new applications
4. **View Deployments**: See ArgoCD deployment status in Backstage
5. **Check Kubernetes Resources**: View pods, services via Backstage UI

### For Platform Engineers

1. **Access ArgoCD**: http://argocd.localhost
2. **Monitor Applications**: Check sync status, health
3. **Manage GitOps**: Commit changes to Git → ArgoCD auto-syncs
4. **Add Templates**: Create new Backstage templates in `backstage/templates/`

## Customization

### Add GitHub Integration

Update [infrastructure/kubernetes/backstage/app-config.yaml](infrastructure/kubernetes/backstage/app-config.yaml):

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}  # Add as environment variable
```

### Add Software Template

1. Create template in `backstage/templates/my-template/`
2. Reference in `backstage/templates/all-templates.yaml`
3. Commit and push to Git
4. Refresh Backstage catalog

### Deploy Your Application

1. Create ArgoCD application manifest in `gitops/applications/my-app.yaml`
2. Commit and push to Git
3. ArgoCD automatically syncs and deploys

## Troubleshooting

### ArgoCD Not Accessible

```powershell
# Check ArgoCD pods
kubectl get pods -n argocd

# Check service
kubectl get svc -n argocd argocd-server

# Check ingress
kubectl get ingress -n argocd
```

### Backstage Not Starting

```powershell
# Check PostgreSQL is running
kubectl get pods -n backstage

# Check logs
kubectl logs -n backstage deployment/backstage

# Check database connection
kubectl exec -n backstage deployment/backstage -- env | grep POSTGRES
```

### Ingress Not Working

```powershell
# Check NGINX Ingress Controller
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -A

# Verify hosts file has entries for *.localhost
```

### Application Won't Sync

```powershell
# Check ArgoCD application status
kubectl describe application <app-name> -n argocd

# Force sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {"revision": "HEAD"}}}'
```

## Production Considerations

When moving to production:

1. **Enable TLS**: Use cert-manager with Let's Encrypt
2. **Configure OAuth**: Replace guest auth with GitHub/Azure AD
3. **Add Monitoring**: Integrate Prometheus/Grafana
4. **Backup Database**: Setup PostgreSQL backups
5. **Update Hosts**: Use real domain names instead of .localhost
6. **Secrets Management**: Use external secrets operator or Vault
7. **Resource Limits**: Adjust CPU/memory based on usage
8. **High Availability**: Scale replicas for critical services

## Next Steps

1. ✅ Access Backstage at http://backstage.localhost
2. ✅ Explore the service catalog
3. ✅ Try creating a new service from a template
4. ✅ Monitor deployments in ArgoCD
5. ✅ Add your own applications to the catalog

## Summary

**You now have a production-ready IDP architecture running locally:**
- ✅ Backstage as the single developer portal
- ✅ ArgoCD for GitOps-based deployments
- ✅ NGINX Ingress for routing
- ✅ App-of-Apps pattern for infrastructure management
- ✅ No unnecessary abstraction layers

**Simple, clean, and follows industry best practices!**
