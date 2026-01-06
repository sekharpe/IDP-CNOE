# Internal Developer Portal (IDP) Infrastructure

A production-ready Internal Developer Portal built with **Backstage** and **ArgoCD**, optimized for local development and cloud deployment.

## 🎯 Quick Start (Local Development)

**Prerequisites**: Docker Desktop with Kubernetes enabled

```powershell
# 1. Add to hosts file (C:\Windows\System32\drivers\etc\hosts):
127.0.0.1 backstage.localhost argocd.localhost

# 2. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 4. Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"

# 5. Deploy the IDP (App-of-Apps pattern)
kubectl apply -f gitops/app-of-apps/bootstrap.yaml

# 6. Access services
# Backstage: http://backstage.localhost
# ArgoCD: http://argocd.localhost
```

**See detailed guide**: [docs/LOCAL_SETUP.md](docs/LOCAL_SETUP.md)

## 📋 What's Included

### Core IDP Components
✅ **Backstage** - Developer portal with service catalog, templates, and docs  
✅ **ArgoCD** - GitOps-based continuous delivery  
✅ **NGINX Ingress** - Traffic routing and ingress  
✅ **PostgreSQL** - Backstage database  

### Infrastructure as Code
✅ **Kubernetes manifests** with Kustomize  
✅ **GitOps** with app-of-apps pattern  
✅ **Terraform** for Azure infrastructure  
✅ **CI/CD pipelines** for GitHub Actions & Azure DevOps  

### Removed (Simplified Architecture)
❌ CNOE platform container (unnecessary abstraction)  
✅ Direct Backstage access (industry standard)

## 🏗️ Architecture Overview

**Production-Ready IDP Architecture:**

```
┌─────────────────────────────────────┐
│          Developers                 │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│      NGINX Ingress Controller       │
└───────┬─────────────────────┬───────┘
        │                     │
        ↓                     ↓
┌──────────────┐      ┌──────────────┐
│  Backstage   │◄─────│   ArgoCD     │
│  (Portal)    │ APIs │  (GitOps)    │
└──────────────┘      └──────────────┘
        │                     │
        └─────────┬───────────┘
                  ↓
        ┌──────────────────┐
        │   Kubernetes     │
        │   (Docker Desktop│
        │    or Cloud)     │
        └──────────────────┘
└────────┘   └─────────┘   └──────────┘
```

## 📚 Documentation

- **[Quick Start](docs/QUICKSTART.md)** - Get running in 30 minutes
- **[Complete Setup Guide](docs/SETUP_GUIDE.md)** - Detailed step-by-step instructions
- **[Architecture](docs/ARCHITECTURE.md)** - Architecture decisions and design
- **[Operations](docs/OPERATIONS.md)** - Day-2 operations and maintenance

## 📁 Repository Structure

```
.
├── infrastructure/              # Infrastructure as Code
│   ├── azure/
│   │   └── terraform/          # ✅ Terraform configs (cost-optimized)
│   └── kubernetes/            # Kubernetes manifests
│       ├── argocd/           # ✅ ArgoCD GitOps setup
│       ├── backstage/        # ✅ Backstage IDP (deployed)
│       ├── cnoe-platform/    # ✅ CNOE platform services
│       ├── ingress/          # ✅ NGINX ingress controller
│       └── namespaces/       # Namespace definitions
├── backstage/                  # ✅ Backstage golden path templates
│   └── templates/
│       └── azure-landing-zone/ # Azure landing zone template
├── gitops/                     # GitOps configurations
│   ├── applications/          # ArgoCD Application manifests
│   ├── app-of-apps/          # App-of-Apps pattern
│   └── overlays/             # Environment overlays (dev/staging/prod)
├── pipelines/                  # CI/CD pipelines
│   ├── azure-devops/         # Azure DevOps YAML pipelines
│   └── github/               # GitHub Actions workflows
├── containers/                 # Container definitions
│   └── platform-services/    # ✅ CNOE platform containers
├── scripts/                    # ✅ Deployment automation
│   ├── deploy.sh            # Linux/macOS deployment
│   └── deploy.ps1           # Windows PowerShell deployment
└── docs/                      # ✅ Comprehensive documentation
    ├── QUICKSTART.md         # Quick start guide
    └── SETUP_GUIDE.md        # Complete setup instructions
```

## 🚀 Prerequisites

- Azure subscription with Owner/Contributor access
- Azure CLI (`az --version`)
- Terraform >= 1.5.0 (`terraform --version`)
- kubectl (`kubectl version --client`)
- Docker (`docker --version`)
- Git repository (GitHub or Azure DevOps)

## 💰 Cost Breakdown

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| AKS Node | 1x Standard_B2s (2 vCPU, 4GB) | ~$30 |
| Container Registry | Basic SKU | ~$5 |
| Key Vault | Standard SKU | ~$0.50 |
| Log Analytics | Pay-as-you-go | ~$5-10 |
| **Total** | **Single Node Dev** | **~$40-50** |

💡 **Cost Savings Tips:**
- Stop cluster when not in use: `az aks stop`
- No availability zones in dev
- Minimal disk sizes
- Basic SKUs where possible

## 📦 Components

### ✅ Deployed by Default

- **Backstage** - Full IDP with software templates and service catalog
- **ArgoCD** - GitOps continuous delivery
- **Kubernetes (AKS)** - Single-node cluster
- **Azure Container Registry** - Container image storage
- **Key Vault** - Secrets management
- **NGINX Ingress** - HTTP/HTTPS routing
- **Azure Landing Zone Template** - Golden path for infrastructure

### 📦 Optional (Add Later)

- **Monitoring** - Prometheus/Grafana stack
- **Service Mesh** - Istio/Linkerd (for production)
- **Additional Templates** - Node.js, Python, React apps

## 🔄 CI/CD Integration

### GitHub Actions
```bash
# Use workflows in pipelines/github/
# Configure repository secrets for Azure authentication
```

### Azure DevOps
```bash
# Use pipelines in pipelines/azure-devops/
# Configure service connections
```

## 🎯 Next Steps After Deployment

1. **Access Backstage**
   ```bash
   kubectl port-forward -n backstage svc/backstage 7007:7007
   # Open http://localhost:7007
   ```

2. **Configure Integrations**
   - Add Azure DevOps/GitHub tokens
   - Configure Azure service principal
   - Update app-config.yaml with your organization details

3. **Create First Landing Zone**
   - Use "Azure Landing Zone" template in Backstage
   - Fill in project details
   - Pipeline automatically provisions infrastructure

4. **Add More Templates**
   - Create templates for your common use cases
   - Add to backstage/templates/ directory

## 🛠️ Operations

### Access Backstage

```bash
# Port forward to Backstage
kubectl port-forward -n backstage svc/backstage 7007:7007
# Open http://localhost:7007

# Access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open https://localhost:8080
```

### Monitor Resources

```bash
# Check all pods
kubectl get pods -A

# Check platform status
kubectl get pods -n cnoe-platform

# View logs
kubectl logs -n cnoe-platform -l app=cnoe-platform
```

### Scale Up (When Ready)

Update [terraform.tfvars](infrastructure/azure/terraform/terraform.tfvars):
```hcl
aks_node_count = 3
aks_node_vm_size = "Standard_D2s_v3"
enable_auto_scaling = true
min_node_count = 2
max_node_count = 10
```

Then apply:
```bash
terraform apply
```

## 🔒 Security

- ✅ RBAC enabled with Azure AD integration
- ✅ Secrets stored in Azure Key Vault
- ✅ Non-root container execution
- ✅ Network policies ready
- ✅ Pod security standards

## 🐛 Troubleshooting

See [SETUP_GUIDE.md](docs/SETUP_GUIDE.md#troubleshooting) for common issues.

**Quick checks:**
```bash
# Check node status
kubectl get nodes

# Check pod health
kubectl get pods -A

# View events
kubectl get events -A --sort-by='.lastTimestamp'
```

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 License

MIT License - See LICENSE file for details

## 🆘 Support

- 📖 **Documentation:** [docs/](docs/)
- 🐛 **Issues:** GitHub Issues
- 💬 **Discussions:** GitHub Discussions

## 🎓 Learn More

- [CNOE Framework](https://cnoe.io/)
- [Backstage](https://backstage.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Platform Engineering](https://platformengineering.org/)

---

**Built with ❤️ for Platform Engineers**
