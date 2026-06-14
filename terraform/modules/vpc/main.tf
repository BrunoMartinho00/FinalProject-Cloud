resource "aws_vpc" "projeto_vpc" {
  cidr_block           = "10.0.0.0/16" # Cria a rede global do projeto
  enable_dns_support   = true # Permite que as máquinas dentro da rede tenham nomes legíveis em vez de apenas números IP
  enable_dns_hostnames = true # Permite que as máquinas dentro da rede tenham nomes legíveis em vez de apenas números IP
  tags                 = { Name = "ProjetoFinal-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.projeto_vpc.id # Cria um router virtual e liga-o à VPC.Permite a rede falar coma internet
  tags   = { Name = "ProjetoFinal-IGW" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.projeto_vpc.id
  cidr_block              = "10.0.1.0/24" # Corta uma fatia da rede para ser a parte pública
  map_public_ip_on_launch = true # qualquer máquina que nasça ganha automaticamente um IP público para a internet
  availability_zone       = "us-east-1a"
  tags                    = { Name = "ProjetoFinal-Public-Subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.projeto_vpc.id
  # Qualquer trafego que queira ir para a internet, tem que passar pelo internet gateway
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
  availability_zone = "us-east-1a" # Cria fatias privadas em zonas físicas (data centers) diferentes para garantir redundância à base de dados
  tags              = { Name = "ProjetoFinal-Private-Subnet-1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.projeto_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "ProjetoFinal-Private-Subnet-2" }
}

# Agrupa as duas sub-redes privadas. A AWS obriga a que uma base de dados ocupe pelo menos duas zonas físicas por questões de segurança.
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "projeto-final-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags       = { Name = "ProjetoFinal-DB-Subnet-Group" }
}