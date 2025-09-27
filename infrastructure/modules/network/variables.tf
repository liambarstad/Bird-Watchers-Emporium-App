variable "aws_region" {
    description = "The AWS region of the application"
    type = string
}

variable "environment" {
    description = "The environment of the application"
    type = string
}

variable "cidr_block" {
    description = "The CIDR block for the VPC"
    type = string
}

variable "az_count" {
    description = "Number of availability zones to use"
    type = number
    default = 2
}