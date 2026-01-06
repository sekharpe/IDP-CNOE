# Azure Infrastructure - Terraform

This directory contains Terraform configurations for provisioning Azure resources for the CNOE platform.

## Structure

- `providers.tf` - Provider configurations
- `variables.tf` - Variable definitions
- `main.tf` - Main resource definitions
- `outputs.tf` - Output values
- `terraform.tfvars.example` - Example variable values

## Prerequisites

1. Install Terraform (>= 1.5.0)
2. Azure CLI installed and logged in
3. Appropriate Azure subscription permissions

## Setup

### 1. Initialize Terraform

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# Update environment, location, and other parameters

# Initialize Terraform
terraform init
```

### 2. Configure Backend (Optional but Recommended)

Create a storage account for Terraform state:

```bash
# Create resource group for state
az group create --name terraform-state-rg --location eastus

# Create storage account
az storage account create \
  --name tfstate$RANDOM \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name <storage-account-name>
```

Update `providers.tf` backend configuration with your values.

### 3. Plan and Apply

```bash
# Review planned changes
terraform plan

# Apply changes
terraform apply

# Or use a plan file
terraform plan -out=tfplan
terraform apply tfplan
```

## Resources Created

- **Resource Group** - Container for all resources
- **Virtual Network** - Network for AKS
- **AKS Cluster** with:
  - System node pool with auto-scaling
  - Azure CNI networking
  - Azure RBAC integration
  - Log Analytics integration
  - Key Vault secrets provider
  - Azure Policy
- **Container Registry** - Private registry for images
- **Key Vault** - Secrets management
- **Log Analytics Workspace** - Monitoring and logging

## Environment-Specific Deployments

### Development
```bash
terraform workspace new dev
terraform apply -var-file="terraform.tfvars"
```

### Production
```bash
terraform workspace new prod
terraform apply -var="environment=prod" -var="aks_node_count=5" -var="aks_node_vm_size=Standard_D4s_v3"
```

## Post-Deployment

### Get AKS Credentials
```bash
# Use the output command
terraform output -raw get_credentials_command | bash

# Or manually
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)
```

### Verify Deployment
```bash
kubectl get nodes
kubectl cluster-info
```

### Login to ACR
```bash
az acr login --name $(terraform output -raw acr_name)
```

## Destroying Resources

```bash
# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=azurerm_kubernetes_cluster.main
```

## Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| environment | Environment name (dev/staging/prod) | dev |
| location | Azure region | eastus |
| prefix | Resource name prefix | cnoe |
| kubernetes_version | K8s version | 1.28.3 |
| aks_node_count | Number of nodes | 3 |
| aks_node_vm_size | VM size for nodes | Standard_D2s_v3 |
| enable_auto_scaling | Enable auto-scaling | true |
| min_node_count | Min nodes for auto-scaling | 2 |
| max_node_count | Max nodes for auto-scaling | 10 |

## Outputs

All outputs can be viewed with:
```bash
terraform output
```

Key outputs include:
- AKS cluster name and FQDN
- ACR login server
- Key Vault URI
- Commands for getting credentials

## Security Best Practices

1. Store state in Azure Storage with encryption
2. Use Azure AD authentication for AKS
3. Enable RBAC and Azure Policy
4. Store secrets in Key Vault
5. Use managed identities
6. Enable soft delete and purge protection on Key Vault
