variable "subnet_id" {}
variable "security_group_id" {}
variable "key_name" {}

# Filtro de pesquisa na lista de imagens de SO
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id # Usar a imagem encontrada anteriormente
  instance_type          = "t3.small" # Aumentado para aguentar o Kafka
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id] # Coloca a maquina em rede publica e mete firewall de web
  subnet_id              = var.subnet_id # Coloca a maquina em rede publica e mete firewall de web

  # Define o disco rigido
  root_block_device {
    volume_size = 20
    volume_type = "gp2" # SSD
  }
  tags = { Name = "ProjetoFinal-Server" }
}