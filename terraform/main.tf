terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # AQUI ESTÁ A NOVIDADE: O COFRE NA CLOUD
  backend "s3" {
    bucket = "bruno-finalproject-tfstate-123" # Substitui pelo nome único que escolheres
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Obter a Rede (VPC) padrão da AWS
data "aws_vpc" "default" {
  default = true
}

# Obter a imagem (AMI) mais recente do Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 2. Security Group para a Máquina Virtual (EC2)
resource "aws_security_group" "web_sg" {
  name        = "projeto-final-web-sg"
  description = "Permitir trafego HTTP e SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP do Gateway"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH de qualquer lado"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Security Group para a Base de Dados (RDS)
resource "aws_security_group" "db_sg" {
  name        = "projeto-final-db-sg"
  description = "Permitir trafego PostgreSQL apenas da EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL da EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Apenas a EC2 pode aceder!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. A Máquina Virtual (EC2)
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = var.key_name
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Aqui garantimos os 20GB para o Docker não ficar sem espaço
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "ProjetoFinal-Server"
  }
}

# 5. A Base de Dados (RDS PostgreSQL)
resource "aws_db_instance" "postgres_db" {
  identifier           = "projeto-final-db-tf"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true
  publicly_accessible  = true
  
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = "ProjetoFinal-DB"
  }
}