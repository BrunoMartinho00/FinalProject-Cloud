# Módulo oficial da AWS para criar a VPC e toda a rede subjacente
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "projeto-final-vpc"
  cidr = "10.0.0.0/16"

  # Vamos usar duas Availability Zones para garantir redundância
  azs             = ["us-east-1a", "us-east-1b"]
  
  # A base de dados vai ficar aqui (sem acesso à net) [cite: 614]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # As instâncias EC2 com as tuas APIs/Microsserviços vão ficar aqui
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Desligamos o NAT Gateway para garantir que a fatura fica a zero dólares.
  # O NAT Gateway custa cerca de $30/mês mesmo sem ser usado. [cite: 1068-1071]
  enable_nat_gateway   = false 
  single_nat_gateway   = false
  
  enable_dns_hostnames = true
  enable_dns_support   = true
}

output "vpc_id" {
  description = "O ID da VPC criada"
  value       = module.vpc.vpc_id
}