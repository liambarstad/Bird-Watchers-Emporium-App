terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
    required_version = ">= 1.0.0"
}

provider "aws" {
    region  = var.aws_region
    profile = "dev"
}

resource "aws_vpc" "main" {
    cidr_block           = var.cidr_block
    instance_tenancy     = "default"
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = { Name = "${local.resource_tag}-vpc" }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = { Name = "${local.resource_tag}-igw" }
}

// ------------- Public App Subnet Setup ---------------

resource "aws_subnet" "public" {
    for_each          = toset(local.azs)
    vpc_id            = aws_vpc.main.id
    availability_zone = each.value
    cidr_block        = local.public_cidrs[index(local.azs, each.value)]

    tags = { 
        Name = "${local.resource_tag}-public-${element(reverse(split("-", each.value)), 0)}" 
    }
}

resource "aws_route_table" "public" {
    for_each = aws_subnet.public
    vpc_id   = aws_vpc.main.id
}

resource "aws_route" "public_default" {
    for_each               = aws_route_table.public
    route_table_id         = each.value.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
    for_each       = aws_subnet.public
    subnet_id      = each.value.id
    route_table_id = aws_route_table.public[each.key].id
}

// ------------- Private App Subnet Setup ---------------

resource "aws_subnet" "private_app" {
    for_each          = toset(local.azs)
    vpc_id            = aws_vpc.main.id
    availability_zone = each.value
    cidr_block        = local.private_app_cidrs[index(local.azs, each.value)]

    tags = { 
        Name = "${local.resource_tag}-private-app-${element(reverse(split("-", each.value)), 0)}" 
    }
}

resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
    allocation_id = aws_eip.nat.id
    subnet_id     = aws_subnet.public[local.azs[0]].id
    depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_app" {
    for_each = aws_subnet.private_app
    vpc_id   = aws_vpc.main.id
}

resource "aws_route" "private_app_default" {
    for_each               = aws_route_table.private_app
    route_table_id         = each.value.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_app_assoc" {
    for_each       = aws_subnet.private_app
    subnet_id      = each.value.id
    route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_security_group" "private_app_sg" {
    vpc_id = aws_vpc.main.id
    egress { 
        from_port = 0 
        to_port = 0 
        protocol = "-1" 
        cidr_blocks = ["0.0.0.0/0"] 
    }
}

// ------------- Private Data Subnet Setup ---------------

resource "aws_subnet" "data" {
    for_each          = toset(local.azs)
    vpc_id            = aws_vpc.main.id
    availability_zone = each.value
    cidr_block        = local.private_data_cidrs[index(local.azs, each.value)]

    tags = { 
        Name = "${local.resource_tag}-private-data-${element(reverse(split("-", each.value)), 0)}" 
    }
}

resource "aws_route_table" "data" {
    for_each = aws_subnet.data
    vpc_id   = aws_vpc.main.id
}

resource "aws_route_table_association" "data_assoc" {
    for_each       = aws_subnet.data
    subnet_id      = each.value.id
    route_table_id = aws_route_table.data[each.key].id
}

// accessible on port 11434 from private app instances 
resource "aws_security_group" "data_sg" {
    vpc_id = aws_vpc.main.id
    ingress {
        description    = "Allow private app SG"
        from_port      = 11434
        to_port        = 11434
        protocol       = "tcp"
        security_groups = [aws_security_group.private_app_sg.id]
    }
}