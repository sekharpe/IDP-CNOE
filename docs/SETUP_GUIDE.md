# CNOE Platform - Complete Setup Guide

## Overview

This guide walks you through deploying a cost-optimized CNOE (Cloud Native Operational Excellence) Internal Developer Portal for MVP/dev environment using a single-node AKS cluster.

**Estimated Monthly Cost:** ~$40-50 USD

## Prerequisites

Before you begin, ensure you have:

- Azure subscription with Owner or Contributor access
- Azure CLI installed (`az --version`)
- Terraform >= 1.5.0 (`terraform --version`)
- kubectl installed (`kubectl version --client`)
- Docker installed (for building containers)
- Git repository (GitHub or Azure DevOps)

## Architecture

```
┌─────────────────────────────────────────────────┐
│         CNOE Platform Portal (Browser)          │
└─────────────────────────────────────────────────┘
                      ▼
         ┌─────────────────────────┐
         │    Ingress (NGINX)      │
         └─────────────────────────┘
                      ▼
         ┌─────────────────────────┐
         │   CNOE Platform Pod     │
         │  ┌────────────────────┐ │
         │  │ API Gateway :8080  │ │
         │  │ Portal UI   :8081  │ │
         │  │ Docs        :8082  │ │
         │  └────────────────────┘ │
         └─────────────────────────┘
                      ▼
         ┌─────────────────────────┐
         │   ArgoCD (GitOps)       │
         └─────────────────────────┘
                      ▼
         ┌─────────────────────────┐
         │  AKS Single Node        │
         │  Standard_B2s           │
         │  2 vCPU, 4GB RAM        │
         └─────────────────────────┘
```

## Step 1: Deploy Azure Infrastructure

### 1.1 Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 1.2 Navigate to Terraform directory

```bash
cd infrastructure/azure/terraform
```

### 1.3 Review configuration

The `terraform.tfvars` file contains cost-optimized settings:
- Single node AKS cluster
- Standard_B2s VM size
- Basic ACR SKU
- Minimal resource configuration

### 1.4 Initialize and deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure (takes ~10-15 minutes)
terraform apply

# Save outputs
terraform output -json > outputs.json
```

### 1.5 Get AKS credentials

```bash
# Get resource group and cluster name from outputs
RG_NAME=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)

# Configure kubectl
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME

# Verify connection
kubectl get nodes
```

**Expected output:**
```
NAME                                STATUS   ROLES   AGE   VERSION
aks-systempool-12345678-vmss000000  Ready    agent   5m    v1.28.3
```

## Step 2: Deploy ArgoCD

### 2.1 Install ArgoCD

```bash
cd ../../../  # Back to repo root

# Create ArgoCD namespace and deploy
kubectl apply -k infrastructure/kubernetes/argocd/base

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 2.2 Get ArgoCD admin password

```bash
# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
```

### 2.3 Access ArgoCD UI (optional)

```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Username: admin
# Password: <from above>
```

## Step 3: Build and Push Platform Services Container

### 3.1 Get ACR login server

```bash
ACR_NAME=$(terraform output -raw acr_name)
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)

echo "ACR: $ACR_LOGIN_SERVER"
```

### 3.2 Login to ACR

```bash
az acr login --name $ACR_NAME
```

### 3.3 Build and push container

```bash
cd containers/platform-services

# Build the CNOE platform container
docker build -f Dockerfile.cnoe -t cnoe-platform-services:latest .

# Tag for ACR
docker tag cnoe-platform-services:latest $ACR_LOGIN_SERVER/cnoe-platform-services:latest

# Push to ACR
docker push $ACR_LOGIN_SERVER/cnoe-platform-services:latest
```

### 3.4 Update deployment with correct image

```bash
# Update the deployment.yaml with your ACR name
sed -i "s/cnoedevacr.azurecr.io/$ACR_LOGIN_SERVER/g" ../../infrastructure/kubernetes/cnoe-platform/deployment.yaml
```

## Step 4: Deploy CNOE Platform Services

### 4.1 Deploy platform services

```bash
cd ../../  # Back to repo root

# Deploy using kubectl
kubectl apply -k infrastructure/kubernetes/cnoe-platform

# Verify deployment
kubectl get pods -n cnoe-platform
```

**Expected output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
cnoe-platform-services-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### 4.2 Check service

```bash
kubectl get svc -n cnoe-platform
```

## Step 5: Deploy NGINX Ingress Controller

```bash
# Deploy NGINX ingress
kubectl apply -k infrastructure/kubernetes/ingress

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get external IP
kubectl get svc -n ingress-nginx
```

## Step 6: Access the Platform

### Option A: Port Forward (Development)

```bash
# Forward platform portal
kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8081:8081

# Open browser to http://localhost:8081
```

### Option B: Configure Ingress (Production-like)

1. Update your hosts file or DNS:
   ```
   <EXTERNAL-IP>  portal.cnoe.local
   <EXTERNAL-IP>  api.cnoe.local
   <EXTERNAL-IP>  docs.cnoe.local
   ```

2. Access via:
   - Portal: http://portal.cnoe.local
   - API: http://api.cnoe.local
   - Docs: http://docs.cnoe.local

## Step 7: Bootstrap GitOps (Optional)

### 7.1 Configure Git repository

Update the repository URL in `gitops/applications/cnoe-platform.yaml`:

```yaml
source:
  repoURL: https://github.com/your-org/idp.git  # Your repo
  targetRevision: main
```

### 7.2 Push to Git

```bash
git add .
git commit -m "Configure CNOE platform for dev environment"
git push origin main
```

### 7.3 Deploy app-of-apps

```bash
# Deploy the bootstrap application
kubectl apply -f gitops/app-of-apps/bootstrap.yaml

# ArgoCD will now manage all platform apps
```

## Step 8: Verify Everything

### 8.1 Check all components

```bash
# Check namespaces
kubectl get ns

# Check all pods
kubectl get pods -A

# Check ArgoCD applications (if using GitOps)
kubectl get applications -n argocd
```

### 8.2 Test API endpoints

```bash
# Get platform info
curl http://localhost:8081/api/info

# Check health
curl http://localhost:8081/health

# View catalog
curl http://localhost:8081/api/catalog
```

## Cost Optimization Tips

1. **Stop cluster when not in use:**
   ```bash
   az aks stop --name $AKS_NAME --resource-group $RG_NAME
   az aks start --name $AKS_NAME --resource-group $RG_NAME
   ```

2. **Monitor costs:**
   ```bash
   az consumption usage list --start-date 2025-12-01 --end-date 2025-12-31
   ```

3. **Set budget alerts:**
   - Configure in Azure Portal > Cost Management + Billing

## Next Steps

### Deploy Backstage (When Ready)

```bash
# Backstage infrastructure is already prepared
kubectl apply -k infrastructure/kubernetes/backstage

# Follow Backstage setup docs for configuration
```

### Configure CI/CD

Choose your platform:

#### GitHub Actions
```bash
# Use pipelines/github/infrastructure.yml
# Configure secrets in GitHub repo settings
```

#### Azure DevOps
```bash
# Use pipelines/azure-devops/infrastructure-pipeline.yml
# Configure service connections
```

### Add Service Templates

Create service templates in the portal for:
- Node.js microservices
- Python APIs
- Containerized applications

## Troubleshooting

### Pods not starting

```bash
# Check pod logs
kubectl logs -n cnoe-platform <pod-name>

# Describe pod
kubectl describe pod -n cnoe-platform <pod-name>
```

### ACR pull errors

```bash
# Verify ACR connection
az aks check-acr --name $AKS_NAME --resource-group $RG_NAME --acr $ACR_NAME
```

### Ingress not working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress -n cnoe-platform
```

## Cleanup

To destroy all resources:

```bash
cd infrastructure/azure/terraform
terraform destroy
```

**Warning:** This will delete all resources and data!

## Support and Documentation

- **Platform Docs:** Access at http://localhost:8082 (or docs.cnoe.local)
- **API Documentation:** http://localhost:8080/api/info
- **ArgoCD:** https://localhost:8080 (port-forward)

## Cost Breakdown

| Resource | SKU | Monthly Cost (Approx.) |
|----------|-----|------------------------|
| AKS Node | Standard_B2s (1 node) | $30 |
| ACR | Basic | $5 |
| Key Vault | Standard | $0.50 |
| Log Analytics | Pay-as-you-go | $5-10 |
| **Total** | | **~$40-50** |

## What's Included

✅ Single-node AKS cluster  
✅ Azure Container Registry  
✅ Key Vault for secrets  
✅ Log Analytics & monitoring  
✅ ArgoCD for GitOps  
✅ CNOE Platform Services  
✅ NGINX Ingress Controller  
✅ Backstage infrastructure (ready to deploy)  
✅ CI/CD pipeline templates  

## What's NOT Included (Save for Later)

❌ Multi-node cluster  
❌ Auto-scaling  
❌ Production-grade TLS certificates  
❌ Advanced monitoring (Prometheus/Grafana)  
❌ Backup solutions  
❌ Multi-environment setup  

These can be added later as your platform matures!
