variable "db_subnet_group_name" {}
variable "security_group_id" {}
variable "db_username" {}
variable "db_password" {}

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
  publicly_accessible  = false # PROTEGIDA DA INTERNET!

  vpc_security_group_ids = [var.security_group_id]
  db_subnet_group_name   = var.db_subnet_group_name

  tags = { Name = "ProjetoFinal-DB" }
}