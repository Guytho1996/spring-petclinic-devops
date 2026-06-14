output "resource_group_name" {
  description = "Resource group principal creado para la aplicacion."
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Region de Azure usada por la infraestructura."
  value       = azurerm_resource_group.main.location
}

output "virtual_network_id" {
  description = "ID de la red virtual principal."
  value       = azurerm_virtual_network.main.id
}

output "aks_cluster_name" {
  description = "Nombre del cluster Azure Kubernetes Service."
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "FQDN del API server de AKS."
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_outbound_ip_address" {
  description = "IP publica estatica usada por AKS para salir hacia PostgreSQL."
  value       = azurerm_public_ip.aks_outbound.ip_address
}

output "aks_get_credentials_command" {
  description = "Comando para configurar kubectl contra el cluster AKS."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer de AKS para Workload Identity."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "acr_name" {
  description = "Nombre de Azure Container Registry."
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Servidor login de Azure Container Registry."
  value       = azurerm_container_registry.main.login_server
}

output "postgres_server_name" {
  description = "Nombre del Azure Database for PostgreSQL Flexible Server existente."
  value       = data.azurerm_postgresql_flexible_server.existing.name
}

output "postgres_fqdn" {
  description = "FQDN del PostgreSQL Flexible Server existente."
  value       = data.azurerm_postgresql_flexible_server.existing.fqdn
}

output "postgres_database_name" {
  description = "Nombre de la base de datos PostgreSQL seleccionada para este entorno."
  value       = var.db_name
}

output "postgres_jdbc_url" {
  description = "JDBC URL para configurar POSTGRES_URL en Kubernetes o GitHub Actions."
  value       = "jdbc:postgresql://${data.azurerm_postgresql_flexible_server.existing.fqdn}:5432/${var.db_name}?sslmode=require"
}

output "postgres_admin_username" {
  description = "Usuario PostgreSQL configurado para la aplicacion."
  value       = var.db_admin_username
}

output "assets_storage_account_name" {
  description = "Storage Account equivalente a S3 para artefactos del proyecto."
  value       = azurerm_storage_account.assets.name
}

output "assets_storage_container_name" {
  description = "Container privado para artefactos del proyecto."
  value       = azurerm_storage_container.artifacts.name
}

output "log_analytics_workspace_id" {
  description = "ID de Log Analytics para observabilidad de AKS."
  value       = azurerm_log_analytics_workspace.main.id
}
