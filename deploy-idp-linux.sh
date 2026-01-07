#!/bin/bash
##############################################################################
# Complete IDP Deployment Script for Linux VM
# Deploys: K3s, ArgoCD, Backstage, PostgreSQL, NGINX Ingress
##############################################################################

set -e  # Exit on error

# Configuration
REPO_URL="${1:-https://github.com/sekharpe/IDP-CNOE}"
DOMAIN="${2:-idp.local}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
AZURE_DEVOPS_TOKEN="${AZURE_DEVOPS_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
cat << "EOF"
========================================
 Internal Developer Portal Installer
 Linux VM Edition
========================================
EOF
echo -e "${NC}"

##############################################################################
# STEP 1: System Prerequisites
##############################################################################
install_prerequisites() {
    echo -e "\n${YELLOW}[STEP 1/8] Installing Prerequisites...${NC}"
    
    # Update system
    echo "  → Updating system packages..."
    sudo apt-get update -qq
    
    # Install basic tools
    echo "  → Installing basic tools..."
    sudo apt-get install -y -qq \
        curl \
        wget \
        git \
        jq \
        unzip \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common
    
    echo -e "${GREEN}  ✓ Prerequisites installed${NC}"
}

##############################################################################
# STEP 2: Install K3s Kubernetes
##############################################################################
install_k3s() {
    echo -e "\n${YELLOW}[STEP 2/8] Installing K3s Kubernetes...${NC}"
    
    if command -v k3s &> /dev/null; then
        echo -e "${GREEN}  ✓ K3s already installed${NC}"
        return
    fi
    
    echo "  → Installing K3s (lightweight Kubernetes)..."
    curl -sfL https://get.k3s.io | sh -s - \
        --write-kubeconfig-mode 644 \
        --disable traefik \
        --disable servicelb
    
    # Wait for K3s to be ready
    echo "  → Waiting for K3s to be ready..."
    sleep 15
    sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Set up kubectl config
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    
    echo -e "${GREEN}  ✓ K3s installed and running${NC}"
}

##############################################################################
# STEP 3: Install kubectl
##############################################################################
install_kubectl() {
    echo -e "\n${YELLOW}[STEP 3/8] Installing kubectl...${NC}"
    
    if command -v kubectl &> /dev/null; then
        echo -e "${GREEN}  ✓ kubectl already installed${NC}"
        return
    fi
    
    echo "  → Downloading kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    
    echo -e "${GREEN}  ✓ kubectl installed${NC}"
}

##############################################################################
# STEP 4: Clone Repository
##############################################################################
clone_repository() {
    echo -e "\n${YELLOW}[STEP 4/8] Cloning IDP Repository...${NC}"
    
    REPO_DIR="/opt/idp"
    
    if [ -d "$REPO_DIR" ]; then
        echo "  → Repository exists, pulling latest..."
        cd "$REPO_DIR"
        sudo git pull origin master || sudo git pull origin main
    else
        echo "  → Cloning repository..."
        sudo git clone "$REPO_URL" "$REPO_DIR"
    fi
    
    cd "$REPO_DIR"
    echo -e "${GREEN}  ✓ Repository ready at $REPO_DIR${NC}"
}

##############################################################################
# STEP 5: Create Namespaces
##############################################################################
create_namespaces() {
    echo -e "\n${YELLOW}[STEP 5/8] Creating Kubernetes Namespaces...${NC}"
    
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}  ✓ Namespaces created${NC}"
}

##############################################################################
# STEP 6: Install ArgoCD
##############################################################################
install_argocd() {
    echo -e "\n${YELLOW}[STEP 6/8] Installing ArgoCD...${NC}"
    
    # Install ArgoCD
    echo "  → Installing ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    echo "  → Waiting for ArgoCD to be ready (this may take 2-3 minutes)..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Patch ArgoCD for insecure mode (no TLS) - using ConfigMap method
    echo "  → Configuring ArgoCD for HTTP access..."
    kubectl patch configmap argocd-cmd-params-cm -n argocd \
        --type merge \
        -p='{"data":{"server.insecure":"true"}}' || true
    
    # Restart ArgoCD server to apply changes
    kubectl rollout restart deployment/argocd-server -n argocd
    kubectl rollout status deployment/argocd-server -n argocd --timeout=180s
    
    # Get ArgoCD password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo -e "${GREEN}  ✓ ArgoCD installed${NC}"
    echo -e "${CYAN}    Username: admin${NC}"
    echo -e "${CYAN}    Password: ${ARGOCD_PASSWORD}${NC}"
    
    # Save credentials
    echo "$ARGOCD_PASSWORD" | sudo tee /opt/argocd-password.txt > /dev/null
    
    # Bootstrap GitOps (app-of-apps pattern)
    echo "  → Bootstrapping GitOps app-of-apps pattern..."
    
    # Update repo URLs in GitOps files
    sudo find gitops/app-of-apps -type f -name "*.yaml" -exec sed -i "s|https://github.com/your-org/idp|${REPO_URL}|g" {} \;
    
    # Apply AppProjects
    kubectl apply -f gitops/app-of-apps/appprojects.yaml
    
    # Apply bootstrap (creates root-app)
    kubectl apply -f gitops/app-of-apps/bootstrap.yaml
    
    echo -e "${GREEN}  ✓ GitOps app-of-apps configured${NC}"
}

##############################################################################
# STEP 7: Install NGINX Ingress Controller
##############################################################################
install_ingress() {
    echo -e "\n${YELLOW}[STEP 7/8] Installing NGINX Ingress Controller...${NC}"
    
    echo "  → Installing NGINX Ingress..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
    
    echo "  → Waiting for NGINX Ingress to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    echo -e "${GREEN}  ✓ NGINX Ingress installed${NC}"
}

##############################################################################
# STEP 8: Deploy IDP Components
##############################################################################
deploy_idp_components() {
    echo -e "\n${YELLOW}[STEP 8/8] Deploying IDP Components...${NC}"
    
    cd /opt/idp
    
    # Create secrets for Backstage
    echo "  → Creating Backstage secrets..."
    
    # PostgreSQL password
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    kubectl create secret generic postgres-secrets \
        --from-literal=username=backstage \
        --from-literal=password="$POSTGRES_PASSWORD" \
        --from-literal=host=postgres.backstage.svc.cluster.local \
        --from-literal=port=5432 \
        --namespace=backstage \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Backstage secrets (if tokens provided)
    if [ -n "$GITHUB_TOKEN" ] || [ -n "$AZURE_DEVOPS_TOKEN" ]; then
        echo "  → Creating integration tokens..."
        kubectl create secret generic backstage-secrets \
            --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
            --from-literal=AZURE_DEVOPS_TOKEN="${AZURE_DEVOPS_TOKEN}" \
            --namespace=backstage \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    # Deploy PostgreSQL
    echo "  → Deploying PostgreSQL..."
    
    # Fix StorageClass for K3s (change from hostpath to local-path)
    sudo sed -i 's/storageClassName: hostpath/storageClassName: local-path/' infrastructure/kubernetes/backstage/postgres-pvc.yaml
    
    # Delete existing PVC if it has wrong storageClass
    if kubectl get pvc postgres-pvc -n backstage &>/dev/null; then
        CURRENT_SC=$(kubectl get pvc postgres-pvc -n backstage -o jsonpath='{.spec.storageClassName}')
        if [ "$CURRENT_SC" = "hostpath" ]; then
            echo "  → Deleting old PVC with incorrect storageClass..."
            kubectl delete statefulset postgres -n backstage --ignore-not-found=true
            kubectl delete pvc postgres-pvc -n backstage --ignore-not-found=true
            sleep 5
        fi
    fi
    
    kubectl apply -f infrastructure/kubernetes/backstage/postgres-pvc.yaml
    kubectl apply -f infrastructure/kubernetes/backstage/postgres.yaml
    
    # Wait for PostgreSQL with extended timeout
    echo "  → Waiting for PostgreSQL to be ready (may take up to 5 minutes)..."
    if ! kubectl wait --for=condition=ready pod -l app=postgres -n backstage --timeout=300s 2>/dev/null; then
        echo -e "${YELLOW}  ⚠ PostgreSQL not ready yet, checking status...${NC}"
        kubectl get pods -n backstage -l app=postgres
        kubectl describe pod -l app=postgres -n backstage | tail -20
        echo -e "${YELLOW}  → Continuing anyway, Backstage will retry connection...${NC}"
        sleep 10
    else
        echo -e "${GREEN}  ✓ PostgreSQL ready${NC}"
    fi
    
    # Deploy Backstage RBAC
    echo "  → Deploying Backstage RBAC..."
    kubectl apply -f infrastructure/kubernetes/backstage/rbac.yaml
    
    # Deploy Backstage ConfigMap
    echo "  → Deploying Backstage configuration..."
    kubectl apply -f infrastructure/kubernetes/backstage/app-config.yaml
    
    # Deploy Backstage
    echo "  → Deploying Backstage..."
    kubectl apply -f infrastructure/kubernetes/backstage/deployment.yaml
    kubectl apply -f infrastructure/kubernetes/backstage/service.yaml
    
    # Wait for Backstage with better error handling
    echo "  → Waiting for Backstage to be ready (may take up to 5 minutes)..."
    if ! kubectl wait --for=condition=available --timeout=300s deployment/backstage -n backstage 2>/dev/null; then
        echo -e "${YELLOW}  ⚠ Backstage deployment not ready yet${NC}"
        kubectl get pods -n backstage
        echo -e "${YELLOW}  → Check logs with: kubectl logs -n backstage -l app=backstage${NC}"
        echo -e "${YELLOW}  → Backstage may still be starting, continuing...${NC}"
    else
        echo -e "${GREEN}  ✓ Backstage ready${NC}"
    fi
    
    # Create Ingress resources
    echo "  → Creating Ingress resources..."
    
    # ArgoCD Ingress
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
    
    # Backstage Ingress
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage-ingress
  namespace: backstage
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: backstage.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backstage
            port:
              number: 7000
EOF
    
    echo -e "${GREEN}  ✓ IDP components deployed${NC}"
}

##############################################################################
# STEP 9: Configure /etc/hosts
##############################################################################
configure_hosts() {
    echo -e "\n${YELLOW}[INFO] Configuring hosts file...${NC}"
    
    VM_IP=$(hostname -I | awk '{print $1}')
    
    # Add entries to /etc/hosts if not already present
    if ! grep -q "argocd.${DOMAIN}" /etc/hosts; then
        echo "$VM_IP argocd.${DOMAIN}" | sudo tee -a /etc/hosts
    fi
    
    if ! grep -q "backstage.${DOMAIN}" /etc/hosts; then
        echo "$VM_IP backstage.${DOMAIN}" | sudo tee -a /etc/hosts
    fi
    
    echo -e "${GREEN}  ✓ Hosts configured${NC}"
}

##############################################################################
# STEP 10: Display Results
##############################################################################
display_results() {
    VM_IP=$(hostname -I | awk '{print $1}')
    ARGOCD_PASSWORD=$(cat /opt/argocd-password.txt)
    
    echo -e "\n${GREEN}"
    cat << "EOF"
========================================
 ✓ IDP Deployment Complete!
========================================
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}VM IP Address:${NC}"
    echo -e "  ${VM_IP}"
    
    echo -e "\n${CYAN}ArgoCD (GitOps):${NC}"
    echo -e "  URL:      http://argocd.${DOMAIN}"
    echo -e "  URL:      http://${VM_IP}:$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')"
    echo -e "  Username: admin"
    echo -e "  Password: ${ARGOCD_PASSWORD}"
    
    echo -e "\n${CYAN}Backstage (Developer Portal):${NC}"
    echo -e "  URL:      http://backstage.${DOMAIN}"
    echo -e "  URL:      http://${VM_IP}:$(kubectl get svc backstage -n backstage -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo '7000')"
    echo -e "  Auth:     Guest access enabled"
    
    echo -e "\n${YELLOW}Add to your local machine's hosts file:${NC}"
    echo -e "  ${VM_IP} argocd.${DOMAIN} backstage.${DOMAIN}"
    
    echo -e "\n${YELLOW}Verify deployment:${NC}"
    echo -e "  kubectl get pods -A"
    echo -e "  kubectl get ingress -A"
    
    echo -e "\n${YELLOW}Credentials saved to:${NC}"
    echo -e "  /opt/argocd-password.txt"
    
    echo -e "\n${GREEN}Next Steps:${NC}"
    echo -e "  1. Add the hosts file entry to your local machine"
    echo -e "  2. Access Backstage at http://backstage.${DOMAIN}"
    echo -e "  3. Configure GitHub/Azure DevOps tokens for templates"
    echo -e "  4. See docs/ folder for configuration guides"
    
    echo ""
}

##############################################################################
# Main Execution
##############################################################################
main() {
    echo -e "${BLUE}Repository: ${REPO_URL}${NC}"
    echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
    echo ""
    
    # Check if running as root or with sudo access
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo -e "${RED}This script requires sudo access. Please run with sudo or ensure passwordless sudo is configured.${NC}"
        exit 1
    fi
    
    # Run installation steps
    install_prerequisites
    install_k3s
    install_kubectl
    clone_repository
    create_namespaces
    install_argocd
    install_ingress
    deploy_idp_components
    configure_hosts
    display_results
    
    echo -e "${GREEN}Installation complete! 🚀${NC}"
}

# Run main function
main
