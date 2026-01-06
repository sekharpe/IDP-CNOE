# Backstage Configuration Guide

This guide helps you configure Backstage with Azure DevOps and GitHub integrations.

## Prerequisites

- Backstage deployed and running
- Azure DevOps or GitHub account with admin access
- Azure subscription with permissions to create service principals

## Step 1: Create Azure DevOps Personal Access Token (PAT)

1. Go to Azure DevOps: https://dev.azure.com
2. Click on **User Settings** > **Personal Access Tokens**
3. Click **New Token**
4. Configure:
   - Name: `Backstage Integration`
   - Organization: Select your organization
   - Scopes: 
     - Code: Read & Write
     - Build: Read & Execute
     - Release: Read, Write & Execute
5. Copy the token (save it securely!)

## Step 2: Create GitHub Personal Access Token

1. Go to GitHub: https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Configure:
   - Note: `Backstage Integration`
   - Scopes:
     - `repo` (Full control)
     - `workflow`
     - `admin:org` (Read org)
4. Copy the token

## Step 3: Create Azure Service Principal

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac \
  --name "backstage-sp" \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>

# Output will show:
# {
#   "appId": "xxx",
#   "displayName": "backstage-sp",
#   "password": "xxx",
#   "tenant": "xxx"
# }
```

Save these values!

## Step 4: Update Backstage Configuration

Edit the configmap:

```bash
kubectl edit configmap backstage-app-config -n backstage
```

Update with your values:

```yaml
data:
  app-config.production.yaml: |
    app:
      title: Your Company IDP
      baseUrl: http://backstage.cnoe.local  # Update with your domain
      
    organization:
      name: Your Company Name
      
    integrations:
      azure:
        - host: dev.azure.com
          token: ${AZURE_DEVOPS_TOKEN}  # Your PAT
      github:
        - host: github.com
          token: ${GITHUB_TOKEN}  # Your PAT
    
    auth:
      environment: production
      providers:
        microsoft:
          development:
            clientId: ${AUTH_MICROSOFT_CLIENT_ID}
            clientSecret: ${AUTH_MICROSOFT_CLIENT_SECRET}
            tenantId: ${AUTH_MICROSOFT_TENANT_ID}
```

## Step 5: Create Kubernetes Secrets

```bash
# Create secret for tokens
kubectl create secret generic backstage-secrets \
  --from-literal=AZURE_DEVOPS_TOKEN='your-azure-devops-pat' \
  --from-literal=GITHUB_TOKEN='your-github-token' \
  --from-literal=AUTH_MICROSOFT_CLIENT_ID='your-sp-appId' \
  --from-literal=AUTH_MICROSOFT_CLIENT_SECRET='your-sp-password' \
  --from-literal=AUTH_MICROSOFT_TENANT_ID='your-tenant-id' \
  -n backstage
```

## Step 6: Update Backstage Deployment

Edit deployment to use secrets:

```bash
kubectl edit deployment backstage -n backstage
```

Add environment variables:

```yaml
env:
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
# Add others...
```

## Step 7: Restart Backstage

```bash
kubectl rollout restart deployment/backstage -n backstage
kubectl rollout status deployment/backstage -n backstage
```

## Step 8: Test Integration

1. Access Backstage: http://localhost:7007
2. Go to **Create** tab
3. You should see "Azure Landing Zone" template
4. Try creating a test landing zone

## Configure Template Repository

Update the template location in app-config:

```yaml
catalog:
  locations:
    - type: url
      target: https://dev.azure.com/your-org/your-project/_git/idp?path=/backstage/templates/all-templates.yaml
      rules:
        - allow: [Template]
```

Or for GitHub:

```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/your-org/idp/blob/main/backstage/templates/all-templates.yaml
      rules:
        - allow: [Template]
```

## Troubleshooting

### Templates not showing

```bash
# Check Backstage logs
kubectl logs -n backstage -l app=backstage

# Manually refresh catalog
# In Backstage UI: Settings > Catalog > Manual refresh
```

### Authentication not working

```bash
# Verify secrets exist
kubectl get secrets -n backstage

# Check secret values
kubectl get secret backstage-secrets -n backstage -o yaml
```

### Can't create repos

- Verify PAT has correct permissions
- Check organization/project exists
- Ensure service principal has Contributor role

## Next Steps

1. Create more templates for your use cases
2. Register existing services in catalog
3. Set up automated catalog discovery
4. Configure tech docs for services
