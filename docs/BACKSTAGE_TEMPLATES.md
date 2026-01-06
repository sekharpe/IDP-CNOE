# Using Backstage Templates

## How Templates Appear in Backstage

Once Backstage is deployed and you access http://localhost:7007, here's how to use templates:

### 1. **Navigate to "Create" Page**

In Backstage UI:
```
Home → Create (+ button in sidebar)
```

You'll see a list of available templates:
- ✅ **Create Node.js Microservice** (Demo template - works immediately)
- ✅ **Create Azure Virtual Machine** (Azure template - requires Azure setup)

### 2. **How Templates are Registered**

Templates are registered in [`app-config.yaml`](infrastructure/kubernetes/backstage/app-config.yaml):

```yaml
catalog:
  locations:
    # This tells Backstage where to find templates
    - type: url
      target: https://github.com/your-org/idp/blob/main/backstage/templates/demo-nodejs/template.yaml
      rules:
        - allow: [Template]
```

### 3. **Available Templates**

#### Demo Node.js Template (Ready to Use)
- **Location**: `backstage/templates/demo-nodejs/template.yaml`
- **What it does**: Creates a simple Node.js service scaffold
- **Requirements**: None - works out of the box
- **Great for**: Testing Backstage scaffolding

#### Azure VM Template
- **Location**: `backstage/templates/azure-vm-basic/template.yaml`
- **What it does**: Creates Azure VM infrastructure
- **Requirements**: Azure subscription, Azure DevOps pipeline
- **Great for**: Production infrastructure provisioning

## Template Structure

```
backstage/templates/
├── all-templates.yaml          # Index file (optional)
├── demo-nodejs/                # Demo template
│   ├── template.yaml          # Template definition
│   └── skeleton/              # Files to scaffold
│       ├── catalog-info.yaml  # Service catalog entry
│       └── README.md          # Documentation
└── azure-vm-basic/            # Azure VM template
    ├── template.yaml          # Template definition
    └── README.md              # Instructions
```

## How to Access Templates in Backstage

### Step 1: Deploy IDP
```powershell
.\deploy-idp.ps1 -RepoUrl "https://github.com/yourname/yourrepo.git"
```

### Step 2: Wait for Backstage
```powershell
# Check if Backstage is ready
kubectl get pods -n backstage

# Port-forward to access
kubectl port-forward svc/backstage -n backstage 7007:7007
```

### Step 3: Open Backstage
Navigate to: http://localhost:7007

### Step 4: View Templates
1. Click **"Create"** in the left sidebar (or the **+** button)
2. You'll see your templates listed:
   - **Create Node.js Microservice**
   - **Create Azure Virtual Machine**

### Step 5: Use a Template
1. Click on a template (e.g., "Create Node.js Microservice")
2. Fill in the form:
   - **Name**: `my-test-app`
   - **Description**: `Testing Backstage scaffolding`
   - **Owner**: Select yourself
   - **Port**: `3000`
   - **Replicas**: `1`
3. Click **"Create"**
4. Backstage will scaffold the service

## Template Parameters

Templates use a form-based UI. Example from Node.js template:

```yaml
parameters:
  - title: Application Information
    required:
      - component_id
      - owner
    properties:
      component_id:
        title: Name
        type: string
        description: Unique name for this application
        pattern: '^[a-z0-9-]+$'
```

This creates a form field in Backstage UI where users can input the application name.

## Adding Your Own Template

### 1. Create Template Directory
```
backstage/templates/my-template/
├── template.yaml
└── skeleton/
    ├── catalog-info.yaml
    └── (your template files)
```

### 2. Register in app-config.yaml
```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/your-org/idp/blob/main/backstage/templates/my-template/template.yaml
      rules:
        - allow: [Template]
```

### 3. Commit and Push
```bash
git add backstage/templates/my-template
git commit -m "Add new template"
git push
```

### 4. Refresh Backstage Catalog
In Backstage UI:
```
Home → Settings → Register Existing Component → Refresh
```

Or wait 5 minutes for automatic refresh.

## Troubleshooting

### Template Not Showing Up

1. **Check catalog processing**:
   - Go to: http://localhost:7007/catalog
   - Click on your template name
   - Check "Processing" tab for errors

2. **Check repository URL**:
   - Make sure URL in `app-config.yaml` matches your actual Git repo
   - Template file must be accessible (public repo or authenticated)

3. **Check logs**:
   ```powershell
   kubectl logs -n backstage deployment/backstage -f
   ```

### Template Validation Errors

Validate your template:
```bash
# Install Backstage CLI (optional)
npm install -g @backstage/cli

# Validate template
backstage-cli validate:template backstage/templates/demo-nodejs/template.yaml
```

## Template Actions Available

Common actions you can use in templates:

- `fetch:template` - Fetch template files
- `catalog:register` - Register in service catalog  
- `publish:github` - Publish to GitHub
- `debug:log` - Log messages (for testing)
- `azure:pipeline:run` - Trigger Azure DevOps pipeline

## Example: Using Demo Template

1. Open Backstage: http://localhost:7007
2. Click **"Create"** → **"Create Node.js Microservice"**
3. Fill form:
   ```
   Name: hello-world
   Description: My first Backstage service
   Owner: default/platform-team
   Port: 3000
   Replicas: 1
   ```
4. Click **"Create"**
5. View your new service in the catalog!

## Summary

✅ Templates are defined in `backstage/templates/<template-name>/template.yaml`  
✅ Registered in `app-config.yaml` under `catalog.locations`  
✅ Appear in Backstage UI under **"Create"** page  
✅ Demo template works without external dependencies  
✅ Azure template requires Azure configuration  

**After deployment, navigate to http://localhost:7007/create to see your templates!**
