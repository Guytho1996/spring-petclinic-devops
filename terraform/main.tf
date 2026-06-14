provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  name_prefix = lower(replace("${var.project_name}-${var.environment}", "_", "-"))

  compact_project     = replace(lower(var.project_name), "/[^a-z0-9]/", "")
  compact_environment = replace(lower(var.environment), "/[^a-z0-9]/", "")

  resource_group_name = coalesce(var.resource_group_name, "${local.name_prefix}-rg")
  acr_name            = substr("acr${local.compact_project}${local.compact_environment}${random_string.suffix.result}", 0, 50)
  storage_name        = substr("st${local.compact_project}${local.compact_environment}${random_string.suffix.result}", 0, 24)
  postgres_name       = coalesce(var.postgres_server_name, substr("pg${local.compact_project}${local.compact_environment}${random_string.suffix.result}", 0, 63))

  manage_postgres_database = var.postgres_server_mode == "create" || var.manage_postgres_database

  tags = merge(
    var.tags,
    {
      Application = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# Azure equivalent of the AWS VPC/Subnet layer used by EKS and RDS.
resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Azure equivalent of EKS.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

resource "azurerm_public_ip" "aks_outbound" {
  name                = "${local.name_prefix}-aks-outbound-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${local.name_prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${local.name_prefix}-aks"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.aks_sku_tier
  tags                = local.tags

  default_node_pool {
    name                        = "system"
    node_count                  = var.aks_node_count
    vm_size                     = var.aks_node_vm_size
    vnet_subnet_id              = azurerm_subnet.aks.id
    temporary_name_for_rotation = "syspooltmp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.aks_service_cidr
    dns_service_ip    = var.aks_dns_service_ip

    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.aks_outbound.id]
    }
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
}

# Azure equivalent of GHCR/ECR for container images.
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Azure equivalent of RDS PostgreSQL.
data "azurerm_postgresql_flexible_server" "existing" {
  count = var.postgres_server_mode == "existing" ? 1 : 0

  name                = var.existing_postgres_server_name
  resource_group_name = var.existing_postgres_resource_group_name
}

resource "azurerm_postgresql_flexible_server" "main" {
  count = var.postgres_server_mode == "create" ? 1 : 0

  name                          = local.postgres_name
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = var.postgres_version
  administrator_login           = var.db_admin_username
  administrator_password        = var.postgres_admin_password
  sku_name                      = var.postgres_sku_name
  storage_mb                    = var.postgres_storage_mb
  storage_tier                  = var.postgres_storage_tier
  backup_retention_days         = var.postgres_backup_retention_days
  geo_redundant_backup_enabled  = var.postgres_geo_redundant_backup_enabled
  auto_grow_enabled             = var.postgres_auto_grow_enabled
  public_network_access_enabled = true
  zone                          = var.postgres_zone
  tags                          = local.tags

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.postgres_admin_password != null
      error_message = "postgres_admin_password debe definirse cuando postgres_server_mode = \"create\". Usar TF_VAR_postgres_admin_password para no escribirlo en tfvars."
    }
  }
}

locals {
  postgres_server_id = (
    var.postgres_server_mode == "create"
    ? azurerm_postgresql_flexible_server.main[0].id
    : data.azurerm_postgresql_flexible_server.existing[0].id
  )

  postgres_server_name = (
    var.postgres_server_mode == "create"
    ? azurerm_postgresql_flexible_server.main[0].name
    : data.azurerm_postgresql_flexible_server.existing[0].name
  )

  postgres_fqdn = (
    var.postgres_server_mode == "create"
    ? azurerm_postgresql_flexible_server.main[0].fqdn
    : data.azurerm_postgresql_flexible_server.existing[0].fqdn
  )
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  count = local.manage_postgres_database ? 1 : 0

  name      = var.db_name
  server_id = local.postgres_server_id
  charset   = var.postgres_database_charset
  collation = var.postgres_database_collation

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "aks_outbound" {
  name             = "${local.name_prefix}-aks-outbound"
  server_id        = local.postgres_server_id
  start_ip_address = azurerm_public_ip.aks_outbound.ip_address
  end_ip_address   = azurerm_public_ip.aks_outbound.ip_address
}

# Azure equivalent of S3 for project artifacts. Terraform remote state uses
# Azure Blob Storage too, but that backend is bootstrapped separately.
resource "azurerm_storage_account" "assets" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.storage_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.storage_delete_retention_days
    }
  }
}

resource "azurerm_storage_container" "artifacts" {
  name                  = "artifacts"
  storage_account_id    = azurerm_storage_account.assets.id
  container_access_type = "private"
}
