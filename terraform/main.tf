provider "aws" {
  region = var.aws_region
}

# RECURSO 1: Repositorio Docker (ECR) para la app Spring Boot
resource "aws_ecr_repository" "petclinic_repo" {
  name                 = "${var.project_name}-repo-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# RECURSO 2: Bucket S3 para guardar los archivos de la clínica (ej. fotos de mascotas)
resource "aws_s3_bucket" "petclinic_assets" {
  bucket        = "${var.project_name}-assets-${var.environment}-guido"
  force_destroy = true # Permite destruir el bucket fácilmente si quieres limpiar el entorno

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# RECURSO 3: Almacén de Parámetros (SSM) para la URL de Supabase
resource "aws_ssm_parameter" "supabase_db_url" {
  name        = "/${var.project_name}/${var.environment}/database-url"
  description = "URL de conexión segura hacia Supabase (Session Pooler)"
  type        = "SecureString"
  value       = "jdbc:postgresql://aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}