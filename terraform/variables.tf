variable "aws_region" {
  description = "Región de AWS para desplegar los recursos"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del clúster de EKS"
  type        = string
  default     = "petclinic-prod-cluster"
}

variable "db_instance_class" {
  description = "Clase de la instancia de base de datos RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nombre de la base de datos PostgreSQL en RDS"
  type        = string
  default     = "petclinic"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos RDS"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña para el usuario administrador de RDS"
  type        = string
  default     = "SuperSecurePassword123!"
  sensitive   = true
}
