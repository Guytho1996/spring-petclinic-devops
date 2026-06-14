output "backend_resource_group_name" {
  description = "Resource group que contiene el Storage Account del estado remoto."
  value       = azurerm_resource_group.tfstate.name
}

output "backend_storage_account_name" {
  description = "Storage Account para el backend azurerm."
  value       = azurerm_storage_account.tfstate.name
}

output "backend_container_name" {
  description = "Blob Container del estado remoto."
  value       = azurerm_storage_container.tfstate.name
}

output "backend_key" {
  description = "Blob key sugerida para el estado del modulo principal."
  value       = var.state_key
}

output "backend_hcl" {
  description = "Contenido base para terraform/backend.hcl."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.tfstate.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "${var.state_key}"
    subscription_id      = "${var.subscription_id}"
    use_azuread_auth     = true
  EOT
}
