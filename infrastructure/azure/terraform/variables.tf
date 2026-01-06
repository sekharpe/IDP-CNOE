variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "cnoe"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}

variable "aks_node_count" {
  description = "Default number of nodes in AKS cluster"
  type        = number
  default     = 1 # Minimal cost for dev environment
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s" # Cost-effective for dev/MVP
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for AKS node pool"
  type        = bool
  default     = false # Disabled for cost control in dev
}

variable "min_node_count" {
  description = "Minimum number of nodes for auto-scaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for auto-scaling"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Platform  = "CNOE"
    ManagedBy = "Terraform"
  }
}
