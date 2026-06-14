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
  description = "Nombre de la base PostgreSQL que usara la aplicacion. Usar petclinic_dev en staging y petclinic_prod en production."
  type        = string
  default     = "petclinic_dev"
}

variable "db_admin_username" {
  description = "Usuario administrador de PostgreSQL para la aplicacion."
  type        = string
  default     = "petclinicadmin"
}

variable "postgres_server_mode" {
  description = "Modo de PostgreSQL: existing referencia un Flexible Server ya creado; create aprovisiona un Flexible Server y la base db_name."
  type        = string
  default     = "existing"

  validation {
    condition     = contains(["existing", "create"], var.postgres_server_mode)
    error_message = "postgres_server_mode debe ser existing o create."
  }
}

variable "postgres_server_name" {
  description = "Nombre opcional para el PostgreSQL Flexible Server creado por Terraform. Si es null, se genera automaticamente."
  type        = string
  default     = null
}

variable "postgres_admin_password" {
  description = "Password del administrador cuando postgres_server_mode = create. Pasarlo con TF_VAR_postgres_admin_password o un secret del pipeline."
  type        = string
  default     = null
  sensitive   = true
}

variable "postgres_version" {
  description = "Version de PostgreSQL para servidores creados por Terraform."
  type        = string
  default     = "16"

  validation {
    condition     = contains(["11", "12", "13", "14", "15", "16", "17", "18"], var.postgres_version)
    error_message = "postgres_version debe ser una version soportada por Azure PostgreSQL Flexible Server."
  }
}

variable "postgres_sku_name" {
  description = "SKU del PostgreSQL Flexible Server creado por Terraform."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Storage maximo en MB para el PostgreSQL Flexible Server creado por Terraform."
  type        = number
  default     = 32768

  validation {
    condition = contains([
      32768,
      65536,
      131072,
      262144,
      524288,
      1048576,
      2097152,
      4193280,
      4194304,
      8388608,
      16777216,
      33553408
    ], var.postgres_storage_mb)
    error_message = "postgres_storage_mb debe ser uno de los tamanos soportados por Azure PostgreSQL Flexible Server."
  }
}

variable "postgres_storage_tier" {
  description = "Storage tier opcional para PostgreSQL Flexible Server. Null permite que AzureRM elija el default segun postgres_storage_mb."
  type        = string
  default     = null
}

variable "postgres_backup_retention_days" {
  description = "Dias de retencion de backups para PostgreSQL Flexible Server."
  type        = number
  default     = 7

  validation {
    condition     = var.postgres_backup_retention_days >= 7 && var.postgres_backup_retention_days <= 35
    error_message = "postgres_backup_retention_days debe estar entre 7 y 35."
  }
}

variable "postgres_geo_redundant_backup_enabled" {
  description = "Habilita backup geo-redundante para PostgreSQL Flexible Server."
  type        = bool
  default     = false
}

variable "postgres_auto_grow_enabled" {
  description = "Habilita auto-grow de storage para PostgreSQL Flexible Server."
  type        = bool
  default     = false
}

variable "postgres_zone" {
  description = "Availability Zone opcional para PostgreSQL Flexible Server. Null deja que Azure la asigne."
  type        = string
  default     = null
}

variable "manage_postgres_database" {
  description = "Crea db_name en el servidor PostgreSQL. En modo create siempre se crea; en modo existing activarlo solo si la base no existe o sera importada."
  type        = bool
  default     = false
}

variable "postgres_database_charset" {
  description = "Charset de la base PostgreSQL creada por Terraform."
  type        = string
  default     = "UTF8"
}

variable "postgres_database_collation" {
  description = "Collation de la base PostgreSQL creada por Terraform."
  type        = string
  default     = "en_US.utf8"
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
