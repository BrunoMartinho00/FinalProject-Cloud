terraform {
  required_version = ">= 1.9" # Versão mínima exigida no guião [cite: 147]
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "projeto-final-a22400694"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "projeto-final-a22400694"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  
  # Isto aplica estas tags automaticamente a TUDO o que for criado [cite: 159-167]
  default_tags {
    tags = {
      Project     = "myproject"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}