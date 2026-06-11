terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    # IMPORTANTE: El nombre del bucket debe ser único en todo el mundo.
    bucket         = "spring-petclinic-tf-state-guido"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "spring-petclinic-tf-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}