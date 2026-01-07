# IDP Deployment on Linux VM - Quick Start Guide

## Prerequisites

- **Linux VM** running Ubuntu 20.04+ or Debian 11+
- **Root/sudo access**
- **Minimum specs**: 4 vCPU, 16GB RAM (see VM sizing guide)
- **Open ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 6443 (K8s API)
- **Internet connectivity**

---

## Quick Installation

### Step 1: Copy the script to your VM

```bash
# Option 1: Download directly on VM
wget https://raw.githubusercontent.com/sekharpe/IDP-CNOE/master/deploy-idp-linux.sh
chmod +x deploy-idp-linux.sh

# Option 2: Clone the entire repo
git clone https://github.com/sekharpe/IDP-CNOE.git
cd IDP-CNOE
chmod +x deploy-idp-linux.sh
```

### Step 2: Run the deployment script

```bash
# Basic installation (uses default domain: idp.local)
sudo ./deploy-idp-linux.sh

# With custom domain
sudo ./deploy-idp-linux.sh https://github.com/sekharpe/IDP-CNOE idp.mycompany.com

# With GitHub token (optional)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
sudo -E ./deploy-idp-linux.sh

# With both GitHub and Azure DevOps tokens
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export AZURE_DEVOPS_TOKEN="your-azure-devops-pat"
sudo -E ./deploy-idp-linux.sh
```

### Step 3: Wait for installation (10-15 minutes)

The script will automatically:
- ✅ Install K3s Kubernetes
- ✅ Install kubectl CLI
- ✅ Deploy ArgoCD
- ✅ Deploy NGINX Ingress
- ✅ Deploy PostgreSQL database
- ✅ Deploy Backstage portal
- ✅ Configure ingress routes
- ✅ Generate secure passwords

---

## What Gets Installed

| Component | Purpose | Namespace | Port |
|-----------|---------|-----------|------|
| **K3s** | Lightweight Kubernetes | system | 6443 |
| **ArgoCD** | GitOps deployment | argocd | 80/443 |
| **Backstage** | Developer portal | backstage | 7000 |
| **PostgreSQL** | Database | backstage | 5432 |
| **NGINX Ingress** | Load balancer | ingress-nginx | 80/443 |

---

## Post-Installation

### 1. Get your credentials

```bash
# ArgoCD password
cat /opt/argocd-password.txt

# Or retrieve from Kubernetes
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Add VM IP to your local hosts file

Get your VM IP:
```bash
hostname -I | awk '{print $1}'
```

**On your local machine** (not the VM), add this to your hosts file:

**Windows**: `C:\Windows\System32\drivers\etc\hosts`
```
<VM_IP> argocd.idp.local backstage.idp.local
```

**Mac/Linux**: `/etc/hosts`
```
<VM_IP> argocd.idp.local backstage.idp.local
```

### 3. Access the portals

- **Backstage**: http://backstage.idp.local
- **ArgoCD**: http://argocd.idp.local (admin / password-from-step-1)

---

## Verification Commands

```bash
# Check all pods are running
kubectl get pods -A

# Check ArgoCD
kubectl get pods -n argocd

# Check Backstage
kubectl get pods -n backstage

# Check ingress
kubectl get ingress -A

# Check services
kubectl get svc -A

# View logs
kubectl logs -n backstage -l app=backstage -f
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

---

## Troubleshooting

### Issue: Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes
kubectl describe node
```

### Issue: Can't access from browser

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check if NodePort is exposed
kubectl get svc -n ingress-nginx

# Test from VM
curl -H "Host: backstage.idp.local" http://localhost
curl -H "Host: argocd.idp.local" http://localhost
```

### Issue: Backstage shows network error

```bash
# Check if PostgreSQL is running
kubectl get pods -n backstage -l app=postgres

# Check Backstage logs
kubectl logs -n backstage -l app=backstage --tail=100

# Restart Backstage
kubectl rollout restart deployment backstage -n backstage
```

---

## Firewall Configuration

If using Azure VM or cloud provider, ensure these ports are open:

```bash
# Using UFW (Ubuntu)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 6443/tcp  # Kubernetes API (optional, restrict to your IP)
sudo ufw enable
```

**Azure Network Security Group Rules:**
- Allow SSH (22) from your IP
- Allow HTTP (80) from anywhere
- Allow HTTPS (443) from anywhere
- Allow 6443 from your IP (optional, for kubectl access)

---

## Adding Integration Tokens (Post-Install)

### GitHub Token

```bash
kubectl create secret generic backstage-secrets \
  --from-literal=GITHUB_TOKEN="ghp_your_token_here" \
  --namespace=backstage \
  --dry-run=client -o yaml | kubectl apply -f -

# Update deployment to use it
kubectl set env deployment/backstage -n backstage GITHUB_TOKEN="$(kubectl get secret backstage-secrets -n backstage -o jsonpath='{.data.GITHUB_TOKEN}' | base64 -d)"

# Restart
kubectl rollout restart deployment backstage -n backstage
```

### Azure DevOps Token

```bash
kubectl create secret generic backstage-secrets \
  --from-literal=AZURE_DEVOPS_TOKEN="your_pat_here" \
  --namespace=backstage \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl set env deployment/backstage -n backstage AZURE_DEVOPS_TOKEN="$(kubectl get secret backstage-secrets -n backstage -o jsonpath='{.data.AZURE_DEVOPS_TOKEN}' | base64 -d)"

kubectl rollout restart deployment backstage -n backstage
```

---

## Updating the IDP

```bash
# Pull latest code
cd /opt/idp
sudo git pull origin master

# Reapply manifests
kubectl apply -f infrastructure/kubernetes/backstage/app-config.yaml
kubectl rollout restart deployment backstage -n backstage
```

---

## Uninstall

```bash
# Remove IDP components
kubectl delete namespace backstage argocd dev staging prod

# Remove NGINX Ingress
kubectl delete namespace ingress-nginx

# Uninstall K3s completely
/usr/local/bin/k3s-uninstall.sh

# Remove repository
sudo rm -rf /opt/idp
```

---

## Next Steps

1. ✅ Configure GitHub/Azure DevOps tokens (see above)
2. ✅ Update [app-config.yaml](infrastructure/kubernetes/backstage/app-config.yaml) with your organization details
3. ✅ Add your service catalogs to Backstage
4. ✅ Configure Azure VM provisioning templates
5. ✅ Set up TLS certificates (optional, for production)
6. ✅ Configure OAuth authentication (optional, for production)

See [CONFIGURATION_GUIDE.md](docs/CONFIGURATION_GUIDE.md) for detailed configuration.

---

## Support

- Check logs: `kubectl logs -n backstage -l app=backstage`
- View events: `kubectl get events -A --sort-by='.lastTimestamp'`
- Kubernetes dashboard: `kubectl proxy` then visit http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

---

## Script Parameters

```bash
./deploy-idp-linux.sh [REPO_URL] [DOMAIN]

# Examples:
./deploy-idp-linux.sh https://github.com/sekharpe/IDP-CNOE idp.mycompany.com
./deploy-idp-linux.sh https://github.com/myorg/myrepo backstage.local

# With tokens (set as environment variables):
export GITHUB_TOKEN="ghp_xxxx"
export AZURE_DEVOPS_TOKEN="xxxxx"
sudo -E ./deploy-idp-linux.sh
```

---

**Total Installation Time**: ~10-15 minutes (depending on internet speed and VM resources)

**VM Requirements**: See [VM_SIZING.md] for recommended Azure VM configurations
