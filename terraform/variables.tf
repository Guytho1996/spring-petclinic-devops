variable "subscription_id" {
  description = "ID de la suscripcion de Azure donde se aprovisiona la infraestructura."
  type        = string
}

variable "location" {
  description = "Region de Azure para desplegar los recursos."
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Nombre corto del proyecto. Se usa para nombrar recursos."
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Entorno de despliegue, por ejemplo dev, staging o prod."
  type        = string
  default     = "prod"
}

variable "resource_group_name" {
  description = "Nombre opcional del resource group. Si es null, se genera con project_name y environment."
  type        = string
  default     = null
}

variable "tags" {
  description = "Etiquetas adicionales para todos los recursos."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Rango CIDR de la red virtual principal."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "aks_subnet_cidr" {
  description = "Rango CIDR de la subnet usada por AKS."
  type        = string
  default     = "10.40.1.0/24"
}

variable "kubernetes_version" {
  description = "Version de Kubernetes para AKS. Null deja que Azure use la version por defecto soportada."
  type        = string
  default     = null
}

variable "aks_sku_tier" {
  description = "SKU tier del cluster AKS."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier debe ser Free, Standard o Premium."
  }
}

variable "aks_node_count" {
  description = "Cantidad inicial de nodos del node pool system."
  type        = number
  default     = 2

  validation {
    condition     = var.aks_node_count >= 1
    error_message = "aks_node_count debe ser al menos 1."
  }
}

variable "aks_node_vm_size" {
  description = "Tamano de VM para los nodos de AKS."
  type        = string
  default     = "Standard_B2s"
}

variable "aks_service_cidr" {
  description = "CIDR interno para servicios Kubernetes."
  type        = string
  default     = "10.41.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "IP del servicio DNS de Kubernetes dentro de aks_service_cidr."
  type        = string
  default     = "10.41.0.10"
}

variable "acr_sku" {
  description = "SKU de Azure Container Registry."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku debe ser Basic, Standard o Premium."
  }
}

variable "db_name" {
  description = "Nombre de la base PostgreSQL existente que usara la aplicacion. Usar petclinic_dev en staging y petclinic_prod en production."
  type        = string
  default     = "petclinic_dev"
}

variable "db_admin_username" {
  description = "Usuario PostgreSQL que consumira la aplicacion. No se guarda password en Terraform."
  type        = string
  default     = "petclinicadmin"
}

variable "existing_postgres_server_name" {
  description = "Nombre del Azure Database for PostgreSQL Flexible Server existente."
  type        = string
  default     = "petclinic-dev-pg-20260613"
}

variable "existing_postgres_resource_group_name" {
  description = "Resource group donde existe el PostgreSQL Flexible Server."
  type        = string
  default     = "dev-ops"
}

variable "storage_replication_type" {
  description = "Tipo de replicacion para Storage Account de artefactos."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type debe ser un tipo de replicacion valido para Azure Storage."
  }
}

variable "storage_delete_retention_days" {
  description = "Dias de retencion para borrado logico de blobs y containers."
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "Dias de retencion en Log Analytics."
  type        = number
  default     = 30
}
