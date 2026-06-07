output "ec2_public_ip" {
  value       = module.compute.public_ip
  description = "O IP publico da maquina EC2"
}