output "ec2_public_ip" {
  description = "O IP Publico da tua maquina EC2 para fazeres SSH e CURL"
  value       = aws_instance.app_server.public_ip
}

output "rds_endpoint" {
  description = "O link da tua base de dados para o docker-compose.yml"
  value       = aws_db_instance.postgres_db.endpoint
}