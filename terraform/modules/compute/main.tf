variable "subnet_id" {}
variable "security_group_id" {}
variable "key_name" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small" # Aumentado para aguentar o Kafka
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]
  subnet_id              = var.subnet_id

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }
  tags = { Name = "ProjetoFinal-Server" }
}