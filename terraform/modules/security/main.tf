variable "vpc_id" {}

resource "aws_security_group" "web_sg" {
  name        = "projeto-final-web-sg"
  description = "Permitir trafego HTTP e SSH"
  vpc_id      = var.vpc_id

  # Regras de entrada | 0.0.0.0 significa que o o mundo inteiro pode tentar aceder a estas portas
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
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regras de saida (A porta 0 e protocolo -1 significa "deixar a máquina comunicar livremente para o exterior" (ex: para fazer download do Docker))
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "projeto-final-db-sg"
  description = "Permitir trafego PostgreSQL apenas da EC2"
  vpc_id      = var.vpc_id

  # Regras de entrada - Abre a porta 5432 (padrão do PostgreSQL)
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id] # Em vez de aceitar IPs, só permite entrada se quem estiver a tentar aceder usar a firewall web_sg (EC2)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}