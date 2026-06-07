terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "bruno-finalproject-tfstate-123"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
}

module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id
}

module "compute" {
  source            = "./modules/compute"
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security.web_sg_id
  key_name          = var.key_name
}

module "database" {
  source               = "./modules/database"
  db_subnet_group_name = module.vpc.db_subnet_group_name
  security_group_id    = module.security.db_sg_id
  db_username          = var.db_username
  db_password          = var.db_password
}