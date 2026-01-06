# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-${var.environment}-rg"
  location = var.location
  tags     = merge(var.tags, { Environment = var.environment })
}

# Virtual Network for AKS
resource "azurerm_virtual_network" "aks" {
  name                = "${var.prefix}-${var.environment}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/8"]
  tags                = merge(var.tags, { Environment = var.environment })
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.prefix}-${var.environment}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.240.0.0/16"]
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-${var.environment}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 90 : 30
  tags                = merge(var.tags, { Environment = var.environment })
}

resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
  
  tags = merge(var.tags, { Environment = var.environment })
}

# Azure Kubernetes Service
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-${var.environment}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-${var.environment}"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name            = "systempool"
    vm_size         = var.aks_node_vm_size
    vnet_subnet_id  = azurerm_subnet.aks.id
    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"
    zones           = var.environment == "prod" ? ["1", "2", "3"] : null
    
    # Conditional scaling: either fixed count or auto-scaling
    # When auto-scaling is enabled, node_count must be null
    # enable_auto_scaling = var.enable_auto_scaling
    node_count          = var.enable_auto_scaling ? null : var.aks_node_count
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.0.0.0/16"
    dns_service_ip    = "10.0.0.10"
    load_balancer_sku = "standard"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  azure_policy_enabled = true

  auto_scaler_profile {
    balance_similar_node_groups = true
    expander                    = "random"
    max_graceful_termination_sec = 600
  }

  tags = merge(var.tags, { Environment = var.environment })
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${var.prefix}${var.environment}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.environment == "prod" ? "Premium" : (var.environment == "dev" ? "Basic" : "Standard")
  admin_enabled       = false

  dynamic "georeplications" {
    for_each = var.environment == "prod" ? ["westus"] : []
    content {
      location = georeplications.value
      tags     = merge(var.tags, { Environment = var.environment })
    }
  }

  tags = merge(var.tags, { Environment = var.environment })
}

# Attach ACR to AKS
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# Key Vault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}-${var.environment}-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = var.environment == "dev" ? 7 : 90 # Minimal retention for dev
  purge_protection_enabled   = var.environment == "prod" ? true : false # Disable for dev flexibility
  enabled_for_disk_encryption = true
  enabled_for_deployment     = true
  enabled_for_template_deployment = true

  tags = merge(var.tags, { Environment = var.environment })
}

# Grant AKS access to Key Vault
resource "azurerm_role_assignment" "aks_keyvault" {
  principal_id         = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.main.id
}

# Grant current user/SP access to Key Vault for management
resource "azurerm_role_assignment" "current_user_keyvault" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Administrator"
  scope                = azurerm_key_vault.main.id
}
