provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  count   = var.storage_account_name == null ? 1 : 0
  length  = 6
  upper   = false
  special = false
}

locals {
  compact_project     = replace(lower(var.project_name), "/[^a-z0-9]/", "")
  compact_environment = replace(lower(var.environment), "/[^a-z0-9]/", "")

  resource_group_name  = coalesce(var.resource_group_name, "rg-tfstate-${var.project_name}-${var.environment}")
  generated_storage    = var.storage_account_name == null ? substr("sttf${local.compact_project}${local.compact_environment}${random_string.suffix[0].result}", 0, 24) : var.storage_account_name
  storage_account_name = lower(local.generated_storage)

  tags = merge(
    var.tags,
    {
      Application = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "terraform-state"
    }
  )
}

resource "azurerm_resource_group" "tfstate" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "tfstate" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.delete_retention_days
    }

    container_delete_retention_policy {
      days = var.delete_retention_days
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "tfstate_blob_contributor" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
