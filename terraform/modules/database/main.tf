variable "db_subnet_group_name" {}
variable "security_group_id" {}
variable "db_username" {}
variable "db_password" {}

resource "aws_db_instance" "postgres_db" {
  identifier           = "projeto-final-db-tf"
  allocated_storage    = 20
  engine               = "postgres" # instalar o motor do PostgreSQL 15
  engine_version       = "15" # instalar o motor do PostgreSQL 15
  instance_class       = "db.t3.micro" # maquina que vai correr a bd
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true # ao destruir a ic nao guardar copia de segurança
  publicly_accessible  = false # Não ganhar ip publico de internet

  # Aplicar firewall restrita do DB e coloca-a na sub-redes privada
  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = var.db_subnet_group_name

  tags = { Name = "ProjetoFinal-DB" }
}