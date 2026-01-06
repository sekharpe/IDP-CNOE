#!/usr/bin/env pwsh
# Simple IDP Deployment Script for Docker Desktop Kubernetes
# This script only bootstraps ArgoCD - everything else is deployed automatically via GitOps!

param(
    [string]$RepoUrl = "https://github.com/your-org/idp.git",
    [switch]$SkipRepoUpdate = $false
)

$ErrorActionPreference = "Stop"

Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║           Internal Developer Portal Installer             ║
║                   Docker Desktop Edition                  ║
╚═══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow

# Check kubectl
try {
    $kubectlVersion = kubectl version --client --short 2>$null
    Write-Host "  ✅ kubectl: $kubectlVersion" -ForegroundColor Green
} catch {
    Write-Host "  ❌ kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}

# Check Kubernetes context
try {
    $context = kubectl config current-context
    Write-Host "  ✅ Kubernetes context: $context" -ForegroundColor Green
} catch {
    Write-Host "  ❌ No Kubernetes context found. Is Docker Desktop Kubernetes enabled?" -ForegroundColor Red
    exit 1
}

# Check if cluster is reachable
try {
    kubectl get nodes | Out-Null
    Write-Host "  ✅ Kubernetes cluster is reachable" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Validate repository URL
if ($RepoUrl -eq "https://github.com/your-org/idp.git" -and !$SkipRepoUpdate) {
    Write-Host "⚠️  WARNING: Using placeholder repository URL!" -ForegroundColor Red
    Write-Host "   For GitOps to work, you need to:" -ForegroundColor Yellow
    Write-Host "   1. Push this code to a Git repository" -ForegroundColor Yellow
    Write-Host "   2. Run: .\deploy-idp.ps1 -RepoUrl 'https://github.com/yourorg/yourrepo.git'" -ForegroundColor Yellow
    Write-Host ""
    
    $continue = Read-Host "Continue anyway? This will fail when ArgoCD tries to sync (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "📦 Repository URL: $RepoUrl" -ForegroundColor Cyan
Write-Host ""

# Step 1: Install ArgoCD
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Step 1/3: Installing ArgoCD" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "Creating argocd namespace..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - | Out-Null

Write-Host "Installing ArgoCD components (this may take 1-2 minutes)..." -ForegroundColor Yellow
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml | Out-Null

Write-Host "Waiting for ArgoCD server to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd | Out-Null

Write-Host "✅ ArgoCD installed successfully!" -ForegroundColor Green
Write-Host ""

# Step 2: Configure ArgoCD
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Step 2/3: Configuring ArgoCD" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "Configuring insecure mode for local development..." -ForegroundColor Yellow
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' | Out-Null
kubectl rollout restart deployment argocd-server -n argocd | Out-Null
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd | Out-Null

Write-Host "✅ ArgoCD configured!" -ForegroundColor Green
Write-Host ""

# Get admin password
$argocdPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Step 3: Update repository URLs and deploy
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Step 3/3: Deploying IDP via GitOps" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

if (!$SkipRepoUpdate -and $RepoUrl -ne "https://github.com/your-org/idp.git") {
    Write-Host "Updating repository URLs in manifests..." -ForegroundColor Yellow
    
    Get-ChildItem -Path "gitops" -Filter "*.yaml" -Recurse | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $updated = $content -replace 'https://github.com/your-org/idp\.git', $RepoUrl
        if ($content -ne $updated) {
            Set-Content -Path $_.FullName -Value $updated -NoNewline
            Write-Host "  ✅ Updated: $($_.FullName)" -ForegroundColor Gray
        }
    }
    
    Get-ChildItem -Path "infrastructure" -Filter "*.yaml" -Recurse | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $updated = $content -replace 'https://github.com/your-org/idp\.git', $RepoUrl
        if ($content -ne $updated) {
            Set-Content -Path $_.FullName -Value $updated -NoNewline
            Write-Host "  ✅ Updated: $($_.FullName)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Deploying App Projects (RBAC)..." -ForegroundColor Yellow
kubectl apply -f gitops/app-of-apps/appprojects.yaml | Out-Null

Write-Host "Deploying Bootstrap Application..." -ForegroundColor Yellow
kubectl apply -f gitops/app-of-apps/bootstrap.yaml | Out-Null

Write-Host ""
Write-Host "✅ Bootstrap complete! ArgoCD will now deploy everything automatically." -ForegroundColor Green
Write-Host ""

# Wait a bit and show status
Write-Host "Waiting for ArgoCD to sync applications (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Current ArgoCD Applications:" -ForegroundColor Cyan
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "           ✅ IDP Deployment Started!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Access information
Write-Host "📍 Access Information:" -ForegroundColor Cyan
Write-Host ""

Write-Host "ArgoCD UI:" -ForegroundColor Yellow
Write-Host "  URL:      http://localhost:8080" -ForegroundColor White
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: $argocdPassword" -ForegroundColor White
Write-Host "  Command:  kubectl port-forward svc/argocd-server -n argocd 8080:80" -ForegroundColor Gray
Write-Host ""

Write-Host "Backstage Portal (will be available once deployed):" -ForegroundColor Yellow
Write-Host "  URL:      http://localhost:7007" -ForegroundColor White
Write-Host "  Command:  kubectl port-forward svc/backstage -n backstage 7007:7007" -ForegroundColor Gray
Write-Host ""

# Useful commands
Write-Host "📋 Useful Commands:" -ForegroundColor Cyan
Write-Host "  # Watch ArgoCD sync status" -ForegroundColor Gray
Write-Host "  kubectl get applications -n argocd -w" -ForegroundColor White
Write-Host ""
Write-Host "  # Check Backstage deployment" -ForegroundColor Gray
Write-Host "  kubectl get pods -n backstage" -ForegroundColor White
Write-Host ""
Write-Host "  # View Backstage logs" -ForegroundColor Gray
Write-Host "  kubectl logs -n backstage deployment/backstage -f" -ForegroundColor White
Write-Host ""
Write-Host "  # Port-forward ArgoCD" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/argocd-server -n argocd 8080:80" -ForegroundColor White
Write-Host ""
Write-Host "  # Port-forward Backstage" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/backstage -n backstage 7007:7007" -ForegroundColor White
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 The app-of-apps pattern is working!" -ForegroundColor Green
Write-Host "   ArgoCD is now automatically deploying:" -ForegroundColor Yellow
Write-Host "   - NGINX Ingress Controller" -ForegroundColor White
Write-Host "   - Namespaces" -ForegroundColor White
Write-Host "   - Backstage (with PostgreSQL)" -ForegroundColor White
Write-Host ""
Write-Host "   This will take 3-5 minutes. Watch progress with:" -ForegroundColor Yellow
Write-Host "   kubectl get applications -n argocd -w" -ForegroundColor White
Write-Host ""
