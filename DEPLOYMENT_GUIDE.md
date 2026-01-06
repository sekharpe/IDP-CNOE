# Pre-Deployment Checklist

## Things to Update Before Running deploy-idp.ps1

### 1. **Git Repository URL** (REQUIRED for GitOps)

You need to update the repository URL in these files:

#### Files to Update:
- [`gitops/app-of-apps/bootstrap.yaml`](gitops/app-of-apps/bootstrap.yaml) - Line 13
- [`gitops/app-of-apps/platform-apps.yaml`](gitops/app-of-apps/platform-apps.yaml) - Lines 20, 38, 56, 74

**Find and Replace:**
```yaml
# Change this:
repoURL: https://github.com/your-org/idp.git

# To your actual repository:
repoURL: https://github.com/YOURNAME/YOURREPO.git
```

**OR** let the script do it automatically:
```powershell
.\deploy-idp.ps1 -RepoUrl "https://github.com/YOURNAME/YOURREPO.git"
```

### 2. **Hosts File** (REQUIRED for local access)

Add these entries to your hosts file:

**Windows**: `C:\Windows\System32\drivers\etc\hosts`
```
127.0.0.1 backstage.localhost
127.0.0.1 argocd.localhost
```

**Mac/Linux**: `/etc/hosts`
```
127.0.0.1 backstage.localhost
127.0.0.1 argocd.localhost
```

### 3. **Backstage Configuration** (Optional - can be done later)

**File**: [`infrastructure/kubernetes/backstage/app-config.yaml`](infrastructure/kubernetes/backstage/app-config.yaml)

Update these when you're ready to integrate with real services:

#### GitHub Integration (Optional)
```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}  # Add as environment variable
```

#### Azure DevOps Integration (Optional)
```yaml
integrations:
  azure:
    - host: dev.azure.com
      token: ${AZURE_DEVOPS_TOKEN}
```

#### Catalog Locations (Add your services)
```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/YOURORG/YOURREPO/blob/main/backstage/templates/all-templates.yaml
    # Add your service repositories
    - type: url
      target: https://github.com/YOURORG/service1/blob/main/catalog-info.yaml
```

## What the Script Does Automatically

✅ **Installs ArgoCD**
✅ **Configures ArgoCD for local development**
✅ **Creates AppProjects (platform, applications)**
✅ **Deploys the bootstrap application**
✅ **ArgoCD automatically deploys everything else via app-of-apps pattern**

## App-of-Apps Flow

```
1. You run: deploy-idp.ps1
      ↓
2. Script installs ArgoCD
      ↓
3. Script applies: bootstrap.yaml
      ↓
4. Creates: root-app (watches gitops/app-of-apps/)
      ↓
5. root-app deploys:
      ├─ appprojects.yaml (RBAC)
      └─ platform-apps.yaml (infrastructure)
      ↓
6. platform-apps deploys:
      ├─ ArgoCD (self-management)
      ├─ NGINX Ingress
      ├─ Namespaces
      └─ Backstage
      ↓
7. Everything is running! 🎉
```

## Required Changes Summary

### MUST DO (Before Running)

1. **Push this code to a Git repository**
   ```bash
   git init
   git add .
   git commit -m "Initial IDP setup"
   git remote add origin https://github.com/YOURNAME/YOURREPO.git
   git push -u origin main
   ```

2. **Update repository URLs**
   - Option A: Edit files manually (see above)
   - Option B: Let script do it with `-RepoUrl` parameter

3. **Add hosts file entries**
   - Add `*.localhost` entries (see above)

### OPTIONAL (Can Do Later)

1. **Configure GitHub/Azure integration** in Backstage
2. **Add your service catalogs**
3. **Configure OAuth authentication** (replace guest auth)
4. **Add monitoring/observability**

## Deployment Command

After pushing to Git and updating URLs:

```powershell
# With automatic URL update
.\deploy-idp.ps1 -RepoUrl "https://github.com/YOURNAME/YOURREPO.git"

# Or if you manually updated files
.\deploy-idp.ps1 -SkipRepoUpdate
```

## Verification Steps

After deployment:

```powershell
# Check ArgoCD applications
kubectl get applications -n argocd

# Expected output:
# NAME                  SYNC STATUS   HEALTH STATUS
# root-app              Synced        Healthy
# argocd               Synced        Healthy
# backstage            Synced        Healthy
# ingress-nginx        Synced        Healthy
# namespaces           Synced        Healthy

# Check Backstage pods
kubectl get pods -n backstage

# Port-forward to access
kubectl port-forward svc/argocd-server -n argocd 8080:80
kubectl port-forward svc/backstage -n backstage 7007:7007
```

## Access URLs

- **ArgoCD**: http://localhost:8080
  - Username: `admin`
  - Password: (shown by deploy script)

- **Backstage**: http://localhost:7007
  - Guest authentication enabled

## Troubleshooting

**Issue**: ArgoCD shows "ComparisonError"
- **Fix**: Make sure repository URL is correct and repository is accessible

**Issue**: Backstage pod stuck in "Pending"
- **Fix**: Check if PostgreSQL is running: `kubectl get pods -n backstage`

**Issue**: Can't access via *.localhost
- **Fix**: Verify hosts file entries and use port-forward instead

## Summary

**Only 3 things to update:**
1. ✅ Git repository URL (in manifests or via script parameter)
2. ✅ Hosts file entries
3. ✅ Push code to Git

**Then run:**
```powershell
.\deploy-idp.ps1 -RepoUrl "YOUR_REPO_URL"
```

**ArgoCD does the rest automatically via GitOps!** 🚀
