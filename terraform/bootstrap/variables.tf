variable "subscription_id" {
  description = "ID de la suscripcion de Azure donde se crea el backend remoto."
  type        = string
}

variable "location" {
  description = "Region de Azure para el Storage Account del estado remoto."
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Nombre corto del proyecto."
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Entorno del estado remoto."
  type        = string
  default     = "prod"
}

variable "resource_group_name" {
  description = "Resource group del backend remoto. Si es null, se genera automaticamente."
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Nombre globalmente unico del Storage Account para estado remoto. Si es null, se genera automaticamente."
  type        = string
  default     = null
}

variable "container_name" {
  description = "Nombre del Blob Container donde se guarda terraform.tfstate."
  type        = string
  default     = "tfstate"
}

variable "state_key" {
  description = "Ruta del blob de estado para el modulo principal."
  type        = string
  default     = "prod/petclinic.tfstate"
}

variable "storage_replication_type" {
  description = "Tipo de replicacion para el Storage Account del estado."
  type        = string
  default     = "LRS"
}

variable "delete_retention_days" {
  description = "Dias de retencion para borrado logico de blobs y containers."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
}
