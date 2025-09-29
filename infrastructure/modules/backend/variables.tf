variable "aws_region" {
    description = "The AWS region of the application"
    type = string
}

variable "environment" {
    description = "The environment of the application"
    type = string
}

variable "instance_type" {
    description = "EC2 instance type for the backend server"
    type        = string
    default     = "t3.micro"
}

variable "frontend_base_url" {
    description = "Base URL of the frontend application"
    type = string
}

variable "backend_port" {
    description = "Port number for the backend service on EC2"
    type        = number
    default     = 8000
}

variable "private_app_subnet_ids" {
    description = "IDs of the private app subnets"
    type = map(string)
}

variable "private_app_security_group_name" {
    description = "Name of the private app security group"
    type = string
}

variable "data_subnet_ids" {
    description = "IDs of the data subnets"
    type = map(string)
}

variable "data_security_group_name" {
    description = "Name of the data security group"
    type = string
}

variable "ecr_repository_uri" {
    description = "ECR repository URI for the backend Docker image"
    type        = string
}