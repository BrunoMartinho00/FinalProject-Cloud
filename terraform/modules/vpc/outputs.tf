output "vpc_id" { value = aws_vpc.projeto_vpc.id }
output "public_subnet_id" { value = aws_subnet.public_subnet.id }
output "db_subnet_group_name" { value = aws_db_subnet_group.db_subnet_group.name }