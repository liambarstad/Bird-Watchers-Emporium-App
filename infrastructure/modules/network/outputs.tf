output "aws_region" {
    description = "AWS region"
    value       = var.aws_region
}

output "vpc_id" {
    description = "ID of the VPC"
    value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
    description = "CIDR block of the VPC"
    value       = aws_vpc.main.cidr_block
}

output "private_app_subnet_id" {
    description = "IDs of the private app subnets"
    value       = { for k, s in aws_subnet.private_app : k => s.id }
}

output "private_app_cidr_block" {
    description = "CIDR blocks of the private app subnets"
    value       = { for k, s in aws_subnet.private_app : k => s.cidr_block }
}

output "private_app_security_group_id" {
    description = "ID of the private app security group"
    value       = aws_security_group.data_sg.id
}

output "data_subnet_id" {
    description = "IDs of the data subnets"
    value       = { for k, s in aws_subnet.data : k => s.id }
}

output "data_cidr_block" {
    description = "CIDR block of the data subnet"
    value       = { for k, s in aws_subnet.data : k => s.cidr_block }
}

output "data_security_group_id" {
    description = "ID of the data security group"
    value       = aws_security_group.data_sg.id
}