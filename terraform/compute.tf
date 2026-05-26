# ==========================================
# 1. Security Group para as Instâncias EC2
# ==========================================
# Permite tráfego HTTP/HTTPS do exterior e SSH para administração
resource "aws_security_group" "app_sg" {
  name        = "projeto-final-app-sg"
  description = "Security group para os microsservicos"
  vpc_id      = module.vpc.vpc_id # Usando o ID da VPC criada no main.tf

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Em producao, restringir ao teu IP [cite: 360]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 2. Instância EC2 e Chave SSH
# ==========================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Geração de uma chave SSH privada/pública dinamicamente
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Registo da chave pública na AWS
resource "aws_key_pair" "app_key" {
  key_name   = "projeto-final-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Guarda a chave privada no teu computador local para o Ansible usar
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/projeto-final-key.pem"
  file_permission = "0400"
}

# Criação da EC2
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  
  # Associa a chave SSH que acabamos de criar
  key_name                    = aws_key_pair.app_key.key_name
  
  # Força a AWS a dar um IP público a esta máquina
  associate_public_ip_address = true 

  tags = {
    Name = "projeto-final-app-server"
  }
}

# ==========================================
# 3. Security Group para a Base de Dados (RDS)
# ==========================================
# Apenas permite acesso a partir do Security Group da aplicação [cite: 331, 614]
resource "aws_security_group" "db_sg" {
  name        = "projeto-final-db-sg"
  description = "Security group para a base de dados RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432 # Porta PostgreSQL
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Grupo de Sub-redes para colocar o RDS nas sub-redes PRIVADAS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "projeto-final-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "projeto-final-db-subnet-group"
  }
}

# ==========================================
# 4. Base de Dados RDS (PostgreSQL)
# ==========================================
resource "aws_db_instance" "app_db" {
  identifier             = "projeto-final-db"
  instance_class         = "db.t3.micro" # Escalão Free Tier [cite: 974]
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.3"
  username               = "app_user"
  password               = "passwordSuperSegura123!" # Nota: Em producao deve-se usar o AWS Secrets Manager [cite: 362]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false # Reforça que nao pode ser acedida pela internet [cite: 823]
}

# ==========================================
# 5. Filas de Mensagens Assíncronas (SQS)
# ==========================================
# Fila principal
resource "aws_sqs_queue" "main_queue" {
  name                      = "projeto-final-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# Fila Dead-Letter (DLQ) para mensagens que falham repetidamente [cite: 320, 637]
resource "aws_sqs_queue" "dlq" {
  name = "projeto-final-dlq"
}

# ==========================================
# Outputs (Informação útil a mostrar no final)
# ==========================================
output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.app_db.endpoint
}

output "sqs_queue_url" {
  value = aws_sqs_queue.main_queue.url
}