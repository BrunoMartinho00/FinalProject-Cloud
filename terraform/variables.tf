variable "aws_region" {
  description = "A região da AWS onde vamos criar a infraestrutura"
  default     = "us-east-1"
}

variable "db_username" {
  description = "Username da base de dados"
  default     = "app_user"
}

variable "db_password" {
  description = "Password da base de dados"
  default     = "passwordSuperSegura123!"
  sensitive   = true
}

variable "key_name" {
  description = "O nome da chave SSH na AWS"
  default     = "projeto-final-key"
}