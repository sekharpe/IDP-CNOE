# Quick Start - CNOE Platform

Get your CNOE Internal Developer Portal running in under 30 minutes!

## TL;DR - Fast Track

```bash
# 1. Deploy infrastructure
cd infrastructure/azure/terraform
terraform init && terraform apply -auto-approve

# 2. Get AKS credentials
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# 3. Deploy ArgoCD
kubectl apply -k ../../../infrastructure/kubernetes/argocd/base

# 4. Build & push container
cd ../../../containers/platform-services
az acr login --name $(cd ../../infrastructure/azure/terraform && terraform output -raw acr_name)
docker build -f Dockerfile.cnoe -t cnoe-platform-services:latest .
docker tag cnoe-platform-services:latest $(cd ../../infrastructure/azure/terraform && terraform output -raw acr_login_server)/cnoe-platform-services:latest
docker push $(cd ../../infrastructure/azure/terraform && terraform output -raw acr_login_server)/cnoe-platform-services:latest

# 5. Deploy platform
kubectl apply -k ../../infrastructure/kubernetes/cnoe-platform

# 6. Deploy ingress
kubectl apply -k ../../infrastructure/kubernetes/ingress

# 7. Access portal
kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8081:8081
# Open http://localhost:8081
```

## Prerequisites Checklist

- [ ] Azure subscription
- [ ] Azure CLI installed
- [ ] Terraform >= 1.5.0
- [ ] kubectl installed
- [ ] Docker installed

## Step-by-Step

### 1. Deploy Infrastructure (10 min)

```bash
cd infrastructure/azure/terraform
terraform init
terraform apply
```

**What you get:**
- 1x AKS node (Standard_B2s)
- Azure Container Registry
- Key Vault
- Log Analytics

### 2. Connect to Cluster (1 min)

```bash
az aks get-credentials \
  --resource-group cnoe-dev-rg \
  --name cnoe-dev-aks

kubectl get nodes
```

### 3. Deploy ArgoCD (5 min)

```bash
kubectl apply -k infrastructure/kubernetes/argocd/base

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 4. Build Container (5 min)

```bash
cd containers/platform-services

# Login to ACR
az acr login --name cnoedevacr

# Build and push
docker build -f Dockerfile.cnoe -t cnoe-platform-services:latest .
docker tag cnoe-platform-services:latest cnoedevacr.azurecr.io/cnoe-platform-services:latest
docker push cnoedevacr.azurecr.io/cnoe-platform-services:latest
```

### 5. Deploy Platform (3 min)

```bash
kubectl apply -k infrastructure/kubernetes/cnoe-platform

# Wait for pod
kubectl wait --for=condition=ready pod \
  -l app=cnoe-platform -n cnoe-platform --timeout=300s
```

### 6. Deploy Ingress (2 min)

```bash
kubectl apply -k infrastructure/kubernetes/ingress
```

### 7. Access Platform (1 min)

```bash
# Port forward
kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8081:8081

# Open browser
http://localhost:8081
```

## Verification

```bash
# Check all pods are running
kubectl get pods -A

# Expected namespaces:
# - argocd
# - cnoe-platform
# - ingress-nginx
# - backstage (optional)
```

## What's Next?

1. **Configure GitOps:**
   - Update repo URL in `gitops/applications/cnoe-platform.yaml`
   - Push to Git: `git push origin main`
   - Apply bootstrap: `kubectl apply -f gitops/app-of-apps/bootstrap.yaml`

2. **Deploy Backstage (Optional):**
   ```bash
   kubectl apply -k infrastructure/kubernetes/backstage
   ```

3. **Setup CI/CD:**
   - GitHub: Use `pipelines/github/infrastructure.yml`
   - Azure DevOps: Use `pipelines/azure-devops/infrastructure-pipeline.yml`

## Troubleshooting

**Pods not starting?**
```bash
kubectl logs -n cnoe-platform <pod-name>
```

**Can't pull images?**
```bash
az aks check-acr --name cnoe-dev-aks --resource-group cnoe-dev-rg --acr cnoedevacr
```

**Need to reset?**
```bash
terraform destroy
```

## URLs

- **Portal:** http://localhost:8081
- **API:** http://localhost:8080
- **Docs:** http://localhost:8082
- **ArgoCD:** https://localhost:8080 (port-forward)

## Monthly Cost

**~$40-50 USD** for single-node dev environment

Need help? Check the [full setup guide](SETUP_GUIDE.md).
