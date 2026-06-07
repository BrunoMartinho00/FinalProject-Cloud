resource "aws_vpc" "projeto_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ProjetoFinal-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.projeto_vpc.id
  tags   = { Name = "ProjetoFinal-IGW" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.projeto_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags                    = { Name = "ProjetoFinal-Public-Subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.projeto_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Sub-redes Privadas (Para a Base de Dados)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.projeto_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "ProjetoFinal-Private-Subnet-1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.projeto_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "ProjetoFinal-Private-Subnet-2" }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "projeto-final-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags       = { Name = "ProjetoFinal-DB-Subnet-Group" }
}