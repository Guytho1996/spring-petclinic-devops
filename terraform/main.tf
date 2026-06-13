# Configuración del proveedor de AWS
provider "aws" {
  region = var.aws_region
}

# ========================================================
# 1. Recursos de Red: VPC y Subnets
# ========================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "petclinic-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "petclinic-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "petclinic-public-b"
  }
}

# Subnet Group para la Base de Datos RDS
resource "aws_db_subnet_group" "rds" {
  name       = "petclinic-rds-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "petclinic-db-subnet-group"
  }
}

# ========================================================
# 2. Orquestador Kubernetes (Amazon EKS)
# ========================================================
resource "aws_iam_role" "eks" {
  name = "petclinic-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    subnet_ids              = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster
  ]
}

# ========================================================
# 3. Base de Datos Relacional (Amazon RDS PostgreSQL)
# ========================================================
resource "aws_security_group" "rds" {
  name        = "petclinic-rds-sg"
  description = "Permitir acceso a la base de datos RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Permitir solo desde la VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "petclinic-postgres-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  db_name                = var.db_name
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = var.db_instance_class
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true

  tags = {
    Environment = "production"
    Application = "petclinic"
  }
}

# ========================================================
# 4. Almacenamiento de Estado y Archivos (Amazon S3)
# ========================================================
resource "aws_s3_bucket" "assets" {
  bucket        = "petclinic-assets-storage-mycompany"
  force_destroy = true

  tags = {
    Name        = "petclinic-assets-bucket"
    Environment = "production"
  }
}
