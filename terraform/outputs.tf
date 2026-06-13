output "vpc_id" {
  description = "El ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "eks_cluster_endpoint" {
  description = "El endpoint del clúster de Amazon EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  description = "El nombre del clúster de EKS"
  value       = aws_eks_cluster.main.name
}

output "rds_hostname" {
  description = "El DNS de la base de datos de RDS"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "El puerto de escucha de la base de datos de RDS"
  value       = aws_db_instance.postgres.port
}

output "s3_bucket_name" {
  description = "El nombre del bucket S3 para almacenamiento de recursos"
  value       = aws_s3_bucket.assets.id
}
