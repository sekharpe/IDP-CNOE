# Azure VM Basic Template

**Backstage Software Template for creating Azure Virtual Machines**

## How It Works

This template does NOT create a new repository. Instead:

1. **User fills form** in Backstage UI (VM name, subscription ID, region, size, SSH key)
2. **Backstage triggers** Azure DevOps pipeline `create-vm-pipeline.yml`
3. **Pipeline receives parameters** and creates `auto.tfvars`
4. **Terraform code** lives in `infrastructure/terraform/azure-vm/`
5. **Pipeline runs** `terraform apply` to create VM in user's subscription

## Architecture

```
User → Backstage Form → Azure Pipeline → Terraform → Azure VM
                            ↓
                    (parameters passed)
                            ↓
                infrastructure/terraform/azure-vm/
                    ├─ main.tf
                    ├─ variables.tf
                    └─ outputs.tf
```

## Form Fields

- **VM Name**: 3-15 chars, lowercase alphanumeric
- **Subscription ID**: User's Azure subscription
- **Region**: Azure region (eastus, westeurope, etc.)
- **VM Size**: Standard_B1s, B2s, B2ms, or D2s_v3
- **Admin Username**: VM admin user
- **SSH Public Key**: User's SSH public key for access

## Pipeline

Located at: `pipelines/azure-devops/create-vm-pipeline.yml`

The pipeline:
1. Creates `auto.tfvars` from Backstage parameters
2. Runs `terraform validate`
3. Runs `terraform plan`
4. Runs `terraform apply` (with approval gate)
5. Outputs SSH connection string

## Terraform Code

Located at: `infrastructure/terraform/azure-vm/`

Creates:
- Resource Group
- Virtual Network + Subnet
- Public IP (Static)
- Network Security Group (SSH/HTTP/HTTPS)
- Network Interface
- Linux VM (Ubuntu 22.04 LTS)

## Setup

1. Import pipeline in Azure DevOps
2. Create service connection named `Azure-ServiceConnection`
3. Update template.yaml with your org/project names
4. Register template in Backstage

## Benefits

✅ No new repos created  
✅ Single source of truth for Terraform code  
✅ Parameters passed at runtime  
✅ Easy to update and maintain  
✅ Users can't modify infrastructure code  
✅ Consistent deployments
