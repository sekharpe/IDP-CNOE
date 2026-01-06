# Configuration Guide - What You Need to Provide

This guide shows **exactly what to configure and where** to get the IDP running.

---

## 1. AZURE DEVOPS CONFIGURATION

### 1.1 Create Personal Access Token (PAT)

**Steps:**
1. Go to Azure DevOps: `https://dev.azure.com/{your-organization}`
2. Click **User Settings** (top right) → **Personal Access Tokens**
3. Click **+ New Token**
4. Configure:
   - Name: `Backstage-IDP`
   - Expiration: 90 days (or custom)
   - Scopes:
     - ✅ **Code**: Read, Write, Manage
     - ✅ **Build**: Read & Execute
     - ✅ **Release**: Read, Write, Execute
     - ✅ **Project and Team**: Read
5. Click **Create**
6. **COPY THE TOKEN** (you won't see it again!)

**Where to use it:** See section 2.1 below

---

### 1.2 Create Azure Service Connection

**Steps:**
1. In Azure DevOps, go to: **Project Settings** → **Service Connections**
2. Click **New Service Connection**
3. Select **Azure Resource Manager**
4. Choose **Service Principal (automatic)**
5. Configure:
   - Subscription: Select your Azure subscription
   - Resource Group: Leave empty (all resources)
   - Service Connection Name: `Azure-ServiceConnection`
   - ✅ Grant access permission to all pipelines
6. Click **Save**

**Where it's used:** `pipelines/azure-devops/create-vm-pipeline.yml` (line 61, 93, 148)

---

### 1.3 Import Pipeline

**Steps:**
1. In Azure DevOps, go to **Pipelines** → **Pipelines**
2. Click **New Pipeline**
3. Select **Azure Repos Git** or **GitHub** (where your code is)
4. Select your repository
5. Select **Existing Azure Pipelines YAML file**
6. Path: `/pipelines/azure-devops/create-vm-pipeline.yml`
7. Click **Continue**
8. Click **Save** (don't run yet)
9. Rename to: `create-azure-vm`

---

## 2. BACKSTAGE CONFIGURATION

### 2.1 Update Backstage app-config.yaml

**File:** `infrastructure/kubernetes/backstage/app-config.yaml`

**What to change:**

```yaml
# Line 11: Your organization name
organization:
  name: Your Company Name  # ← CHANGE THIS

# Line 14: Your Backstage URL (or keep localhost for dev)
app:
  baseUrl: http://backstage.cnoe.local  # ← CHANGE THIS if needed

# Line 17: Backend URL
backend:
  baseUrl: http://backstage.cnoe.local  # ← CHANGE THIS if needed

# Line 35-37: Add your Azure DevOps PAT
integrations:
  azure:
    - host: dev.azure.com
      token: ${AZURE_DEVOPS_TOKEN}  # ← UNCOMMENT AND CONFIGURE

# Line 38-40: Add GitHub token if using GitHub
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}  # ← UNCOMMENT AND CONFIGURE (optional)

# Line 66: Your default email
scaffolder:
  defaultAuthor:
    name: CNOE Platform
    email: platform@yourcompany.com  # ← CHANGE THIS

# Line 75-76: Update to your repo
locations:
  - type: url
    target: https://dev.azure.com/your-org/your-project/_git/idp?path=/backstage/templates/all-templates.yaml
    # ← CHANGE THIS to your repo URL
```

---

### 2.2 Create Kubernetes Secret for Tokens

**Create secret file:**

```bash
# Create a file: secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: backstage-secrets
  namespace: backstage
type: Opaque
stringData:
  AZURE_DEVOPS_TOKEN: "your-pat-token-here"        # ← FROM STEP 1.1
  GITHUB_TOKEN: "ghp_xxxxxxxxxxxxx"                 # ← OPTIONAL
  POSTGRES_PASSWORD: "strongpassword123"            # ← GENERATE A STRONG PASSWORD
```

**Apply it:**
```bash
kubectl apply -f secrets.yaml
```

---

### 2.3 Update Backstage Deployment to Use Secrets

**File:** `infrastructure/kubernetes/backstage/deployment.yaml`

**Add environment variables (around line 30):**

```yaml
env:
  - name: POSTGRES_HOST
    value: postgres-service
  - name: POSTGRES_PORT
    value: "5432"
  - name: POSTGRES_USER
    value: backstage
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: backstage-secrets
        key: POSTGRES_PASSWORD
  - name: AZURE_DEVOPS_TOKEN
    valueFrom:
      secretKeyRef:
        name: backstage-secrets
        key: AZURE_DEVOPS_TOKEN
  - name: GITHUB_TOKEN
    valueFrom:
      secretKeyRef:
        name: backstage-secrets
        key: GITHUB_TOKEN
```

---

### 2.4 Update Template with Your Azure DevOps Details

**File:** `backstage/templates/azure-vm-basic/template.yaml`

**What to change (line 83-85):**

```yaml
steps:
  - id: trigger-pipeline
    name: Trigger Azure Pipeline to Create VM
    action: azure:pipeline:run
    input:
      organization: your-org           # ← CHANGE: Your Azure DevOps org name
      project: your-project            # ← CHANGE: Your project name
      pipelineName: create-azure-vm    # ← This should match the pipeline name from step 1.3
```

**How to find these:**
- Organization: From your Azure DevOps URL: `https://dev.azure.com/{organization}`
- Project: The project name where you imported the pipeline

---

## 3. AZURE INFRASTRUCTURE

### 3.1 Update Terraform Variables

**File:** `infrastructure/azure/terraform/terraform.tfvars`

**What to change:**

```hcl
# Line 1-3: Your environment details
project_name = "cnoe"                                    # ← CHANGE: Your project name
environment  = "dev"                                     # ← Keep or change
location     = "eastus"                                  # ← CHANGE: Your preferred region

# Line 5: Your Azure AD tenant
azure_tenant_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # ← CHANGE: Your tenant ID

# Line 7-9: Your identity
admin_email = "admin@yourcompany.com"                     # ← CHANGE: Your email

# Line 11: Resource group (optional)
resource_group_name = "cnoe-dev-rg"                       # ← CHANGE if needed
```

**How to find your Tenant ID:**
```bash
az login
az account show --query tenantId -o tsv
```

---

## 4. SUMMARY - CHECKLIST

Before deploying, make sure you have:

### Azure DevOps
- [ ] Created PAT token (step 1.1)
- [ ] Created service connection named `Azure-ServiceConnection` (step 1.2)
- [ ] Imported pipeline as `create-azure-vm` (step 1.3)

### Backstage Configuration
- [ ] Updated app-config.yaml with org name and email (step 2.1)
- [ ] Created Kubernetes secret with PAT token (step 2.2)
- [ ] Updated deployment.yaml with environment variables (step 2.3)
- [ ] Updated template.yaml with Azure DevOps org/project (step 2.4)

### Azure Infrastructure
- [ ] Updated terraform.tfvars with tenant ID and email (step 3.1)
- [ ] Logged into Azure CLI: `az login`

### Deployment
- [ ] Run: `.\scripts\deploy.ps1`
- [ ] Wait for deployment (~10-15 minutes)
- [ ] Access Backstage: `http://localhost:7007`

---

## 5. QUICK REFERENCE

**Your Values to Fill:**

| Item | Where to Get It | Where to Use It |
|------|----------------|-----------------|
| **Azure DevOps PAT** | Azure DevOps → User Settings → PAT | Kubernetes secret |
| **Azure DevOps Org** | URL: `dev.azure.com/{org}` | template.yaml line 83 |
| **Azure DevOps Project** | Your project name in Azure DevOps | template.yaml line 84 |
| **Azure Tenant ID** | `az account show --query tenantId` | terraform.tfvars line 5 |
| **Service Connection** | Created in step 1.2 | Already named correctly |
| **Admin Email** | Your email | terraform.tfvars, app-config.yaml |

---

## 6. TESTING THE SETUP

After deployment:

1. **Access Backstage:** `http://localhost:7007`
2. **Click "Create"** in the sidebar
3. **Select "Create Azure Virtual Machine"**
4. **Fill the form:**
   - VM Name: `testvm01`
   - Subscription ID: Your Azure subscription ID
   - Region: `eastus`
   - VM Size: `Standard_B2s`
   - Admin Username: `azureuser`
   - SSH Public Key: Paste your SSH public key
5. **Click "Create"**
6. **Monitor pipeline** in Azure DevOps
7. **VM should be created** in ~5-10 minutes

---

## 7. TROUBLESHOOTING

### "Pipeline not found"
- Check pipeline name in Azure DevOps matches `create-azure-vm`
- Verify org and project in template.yaml

### "Service connection not found"
- Ensure service connection is named exactly `Azure-ServiceConnection`
- Grant pipeline permissions to the service connection

### "Authentication failed"
- Verify PAT token is correct in Kubernetes secret
- Check token hasn't expired
- Ensure token has correct scopes (Code, Build, Release)

### "Terraform fails"
- Check service connection has permissions on subscription
- Verify subscription ID is correct
- Ensure you're logged into Azure CLI: `az login`
