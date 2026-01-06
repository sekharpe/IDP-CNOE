# Architecture Changes - Production IDP Simplification

## Summary

Removed the CNOE platform container deployment and simplified the architecture to follow industry-standard IDP best practices.

## What Was Removed

### ❌ CNOE Platform Container
- **Files Disabled**:
  - `gitops/applications/cnoe-platform.yaml` (commented out)
  - `infrastructure/kubernetes/cnoe-platform/ingress.yaml` (commented out)
  - Container image build from `containers/platform-services/`

- **Components Removed**:
  - Static landing portal (port 8081)
  - Custom API Gateway (port 8080)
  - Documentation server (port 8082)
  - Supervisord multi-process container
  - kubectl/helm/argocd CLI tools in container
  - nginx inside the CNOE container

- **Why Removed**:
  - Redundant with Backstage (the real developer portal)
  - Adds unnecessary complexity
  - Not standard IDP architecture
  - Hardcoded data instead of real integrations
  - Creates confusion about which portal to use

## What Remains (Core IDP)

### ✅ Backstage - The Developer Portal
- **URL**: `http://backstage.localhost`
- **Purpose**: Single source of truth for developers
- **Features**:
  - Service catalog
  - Software templates (scaffolding)
  - TechDocs
  - ArgoCD integration
  - Kubernetes plugin
  - Authentication (guest mode for dev, OAuth for prod)

### ✅ ArgoCD - GitOps Engine
- **URL**: `http://argocd.localhost`
- **Purpose**: Continuous delivery via GitOps
- **Features**:
  - Automatic sync from Git
  - Application health monitoring
  - Self-healing deployments
  - Rollback capabilities
  - Integrated with Backstage

### ✅ NGINX Ingress Controller
- **Purpose**: Routes external traffic to services
- **Routes**:
  - `backstage.localhost` → Backstage service (port 7007)
  - `argocd.localhost` → ArgoCD service (port 80)

## Architecture Comparison

### Before (Confusing)
```
Developer
    ↓
NGINX Ingress
    ├─→ backstage.cnoe.local → Backstage
    ├─→ argocd.yourdomain.com → ArgoCD
    └─→ portal.cnoe.local → CNOE Platform Container
                               ├─ Static Portal (8081)
                               ├─ API Gateway (8080)
                               ├─ Docs (8082)
                               ├─ nginx (internal)
                               └─ CLI tools (kubectl, helm, argocd)
```

**Problems**:
- Two portals competing (Backstage vs CNOE portal)
- Unclear which one developers should use
- API Gateway had hardcoded data
- Extra complexity with no clear benefit

### After (Clean)
```
Developer
    ↓
NGINX Ingress
    ├─→ backstage.localhost → Backstage (THE Portal)
    └─→ argocd.localhost → ArgoCD (GitOps)
```

**Benefits**:
- Clear single developer portal (Backstage)
- Standard industry architecture
- No confusion about entry points
- Backstage integrates with ArgoCD APIs directly
- Simpler to understand and maintain

## Configuration Changes

### File Updates

| File | Change |
|------|--------|
| `gitops/applications/cnoe-platform.yaml` | Commented out (disabled) |
| `gitops/app-of-apps/platform-apps.yaml` | Updated to only deploy core components |
| `gitops/app-of-apps/bootstrap.yaml` | Updated repository URL |
| `infrastructure/kubernetes/backstage/app-config.yaml` | Changed to `backstage.localhost` |
| `infrastructure/kubernetes/backstage/ingress.yaml` | **CREATED** - New ingress for Backstage |
| `infrastructure/kubernetes/backstage/kustomization.yaml` | Added ingress.yaml reference |
| `infrastructure/kubernetes/argocd/base/ingress.yaml` | Changed to `argocd.localhost`, disabled TLS |
| `infrastructure/kubernetes/cnoe-platform/ingress.yaml` | Commented out (disabled) |
| `docs/LOCAL_SETUP.md` | **CREATED** - Complete local setup guide |
| `README.md` | Updated architecture and quick start |

### Hostname Changes

| Old | New | Purpose |
|-----|-----|---------|
| `backstage.cnoe.local` | `backstage.localhost` | Backstage developer portal |
| `argocd.yourdomain.com` | `argocd.localhost` | ArgoCD GitOps UI |
| `portal.cnoe.local` | ❌ Removed | Was redundant CNOE portal |
| `api.cnoe.local` | ❌ Removed | Was hardcoded API gateway |
| `docs.cnoe.local` | ❌ Removed | Was static docs server |

### Local Development Setup

**Required hosts file entries** (`C:\Windows\System32\drivers\etc\hosts`):
```
127.0.0.1 backstage.localhost
127.0.0.1 argocd.localhost
```

## Developer Experience

### Before
1. Navigate to `portal.cnoe.local` (landing page)
2. See links to Backstage and ArgoCD
3. Click through to Backstage
4. Use Backstage features

**Problems**: Extra hop, unclear value of landing page

### After
1. Navigate to `backstage.localhost` (direct access)
2. Use Backstage features immediately
3. Access ArgoCD from Backstage if needed

**Benefits**: Direct access, no confusion, standard workflow

## What Backstage Provides

All the functionality that was attempted by CNOE platform container:

| Feature | CNOE Container | Backstage | Winner |
|---------|---------------|-----------|--------|
| Service Catalog | Hardcoded list | Dynamic from Git/APIs | ✅ Backstage |
| Templates | Hardcoded list | Real scaffolding | ✅ Backstage |
| Documentation | Static server | TechDocs with search | ✅ Backstage |
| API Endpoints | Custom gateway | Standard Backstage API | ✅ Backstage |
| Portal UI | Custom HTML | Full React app | ✅ Backstage |
| ArgoCD Integration | None | Plugin with live data | ✅ Backstage |
| Kubernetes View | None | Plugin with live data | ✅ Backstage |
| Authentication | None | OAuth/SAML/Guest | ✅ Backstage |

## Migration Path

If you were using the CNOE platform container:

1. **Service Catalog**: Register services in Backstage catalog instead
2. **Templates**: Create Backstage templates (more powerful)
3. **Documentation**: Use TechDocs in Backstage
4. **API Access**: Use Backstage API or direct service APIs
5. **Monitoring**: Use Backstage plugins for ArgoCD/Kubernetes

## Testing the Changes

### Verify Architecture
```powershell
# Check what's deployed
kubectl get applications -n argocd

# Should see:
# - root-app
# - argocd
# - ingress-nginx
# - namespaces
# - backstage

# Should NOT see:
# - cnoe-platform
```

### Access Services
```powershell
# Backstage
Start-Process "http://backstage.localhost"

# ArgoCD
Start-Process "http://argocd.localhost"
```

### Verify Backstage Integration
1. Open Backstage: http://backstage.localhost
2. Navigate to Catalog
3. Check ArgoCD plugin shows deployments
4. Verify Kubernetes plugin shows resources

## Production Deployment

For production on Azure/AWS/GCP:

1. Replace `.localhost` with real domains (e.g., `backstage.yourcompany.com`)
2. Enable TLS with cert-manager
3. Configure OAuth authentication (GitHub, Azure AD, etc.)
4. Add monitoring (Prometheus/Grafana)
5. Setup backups for PostgreSQL
6. Configure external secrets management

## Rollback (If Needed)

If you need to restore CNOE platform container:

1. Uncomment `gitops/applications/cnoe-platform.yaml`
2. Uncomment `infrastructure/kubernetes/cnoe-platform/ingress.yaml`
3. Add cnoe-platform to `platform-apps.yaml`
4. Build and push container image
5. Update image reference in deployment

**Note**: Not recommended - focus on making Backstage work instead.

## Benefits of This Change

✅ **Clarity**: One portal, one entry point for developers  
✅ **Standard**: Follows industry IDP best practices  
✅ **Maintainability**: Less code to maintain  
✅ **Integration**: Better ArgoCD/Kubernetes integration through Backstage  
✅ **Features**: Full Backstage plugin ecosystem  
✅ **Authentication**: Proper OAuth/SAML support  
✅ **Documentation**: TechDocs instead of static pages  
✅ **Scalability**: Backstage is production-ready at scale  

## Questions & Answers

**Q: Do I lose any functionality?**  
A: No - Backstage provides everything the CNOE container attempted to provide, but better.

**Q: What about the CLI tools (kubectl, helm, argocd)?**  
A: If needed for ops tasks, create a separate tooling pod. Developers don't need them - they use Backstage UI.

**Q: Can I still use the CNOE platform container?**  
A: Yes, but only as a platform engineering admin tool, not for application developers.

**Q: Is this the real CNOE architecture?**  
A: The real CNOE reference architecture is just Backstage + ArgoCD + Kubernetes. The container was a learning/demo artifact.

**Q: How do I add my own services?**  
A: Register them in Backstage catalog using `catalog-info.yaml` files in your repos.

## Conclusion

This simplification brings the IDP to industry-standard architecture:
- **Backstage** = The developer portal
- **ArgoCD** = The GitOps engine
- **No redundant layers** = Clean and maintainable

Follow the guide in [docs/LOCAL_SETUP.md](LOCAL_SETUP.md) to get started!
