# -----------------------------------------------------------
# OUTPUTS DE INFRAESTRUCTURA
# -----------------------------------------------------------

output "ecr_repository_url" {
  description = "La URL del repositorio ECR, necesaria para enviar la imagen Docker desde GitHub Actions."
  value       = aws_ecr_repository.petclinic_repo.repository_url
}

output "s3_bucket_name" {
  description = "El nombre del bucket S3 generado para assets de la aplicación."
  value       = aws_s3_bucket.petclinic_assets.bucket
}

output "ssm_parameter_name" {
  description = "La ruta del parámetro de SSM que contiene la conexión a Supabase."
  value       = aws_ssm_parameter.supabase_db_url.name
}