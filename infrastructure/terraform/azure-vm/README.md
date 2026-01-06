# Azure VM Terraform Module

This directory contains Terraform configuration for deploying Azure Virtual Machines through the Backstage IDP.

## How It Works

1. User fills out form in Backstage UI
2. Backstage triggers Azure DevOps pipeline with parameters
3. Pipeline creates `auto.tfvars` from parameters
4. Pipeline runs `terraform apply`
5. VM is created in user's Azure subscription

## Parameters (from Backstage)

- `vm_name` - Name of the VM (3-15 chars, lowercase alphanumeric)
- `azure_subscription_id` - Target Azure subscription
- `location` - Azure region (e.g., eastus, westeurope)
- `vm_size` - VM size (Standard_B1s, Standard_B2s, etc.)
- `admin_username` - VM admin username
- `ssh_public_key` - SSH public key for authentication

## Resources Created

- Resource Group: `{vm_name}-rg`
- Virtual Machine: `{vm_name}`
- Virtual Network: `{vm_name}-vnet` (10.0.0.0/16)
- Subnet: `{vm_name}-subnet` (10.0.1.0/24)
- Public IP: `{vm_name}-pip` (Static)
- Network Security Group: `{vm_name}-nsg` (SSH, HTTP, HTTPS)
- Network Interface: `{vm_name}-nic`

## Manual Deployment (for testing)

```bash
# Create tfvars file
cat > auto.tfvars <<EOF
vm_name              = "testvm01"
azure_subscription_id = "your-subscription-id"
location             = "eastus"
vm_size              = "Standard_B2s"
admin_username       = "azureuser"
ssh_public_key       = "ssh-rsa AAA..."
EOF

# Deploy
terraform init
terraform plan -var-file=auto.tfvars
terraform apply -var-file=auto.tfvars

# Get connection info
terraform output ssh_connection_string
```

## Cleanup

```bash
terraform destroy -var-file=auto.tfvars
```
