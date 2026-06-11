# -----------------------------------------------------------
# VARIABLES DE INFRAESTRUCTURA - SPRING PETCLINIC
# -----------------------------------------------------------

variable "aws_region" {
  description = "La región de AWS donde se desplegarán los recursos del Petclinic."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "El prefijo para nombrar todos los recursos del proyecto."
  type        = string
  default     = "spring-petclinic"
}

variable "environment" {
  description = "El entorno de despliegue actual (ej. dev, qa, prod)."
  type        = string
  default     = "dev"
}