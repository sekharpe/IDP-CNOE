variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,15}$", var.vm_name))
    error_message = "VM name must be lowercase alphanumeric, 3-15 characters."
  }
}

variable "azure_subscription_id" {
  description = "Azure subscription ID where VM will be deployed"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  
  validation {
    condition     = contains(["eastus", "eastus2", "westus2", "centralus", "westeurope", "northeurope"], var.location)
    error_message = "Must be a valid Azure region."
  }
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
  
  validation {
    condition     = contains(["Standard_B1s", "Standard_B2s", "Standard_B2ms", "Standard_D2s_v3"], var.vm_size)
    error_message = "Must be a valid VM size."
  }
}

variable "admin_username" {
  description = "Administrator username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  
  validation {
    condition     = can(regex("^ssh-rsa", var.ssh_public_key))
    error_message = "Must be a valid SSH public key starting with 'ssh-rsa'."
  }
}
