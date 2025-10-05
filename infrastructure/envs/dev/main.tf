locals {
    aws_region  = "us-east-1"
    environment = "dev"
    frontend_base_url = "https://bwe.${local.environment}.liambarstad.com"
    backend_base_url = "https://bwe-api.${local.environment}.liambarstad.com"
}

module "network" {
    source      = "../../modules/network"
    aws_region  = local.aws_region
    environment = local.environment
    cidr_block  = "10.0.0.0/16"
    az_count    = 1 
}

module "frontend" {
    source = "../../modules/frontend"
    aws_region = local.aws_region
    environment = local.environment
    frontend_base_url = local.frontend_base_url
}

module "backend" {
    source      = "../../modules/backend"
    aws_region  = local.aws_region
    environment = local.environment
    instance_type = "t3.micro"   
    frontend_base_url = local.frontend_base_url
    backend_base_url = local.backend_base_url
    backend_port = 8000
    ecr_repository_uri = aws_ecr_repository.backend_repo.repository_url

    private_app_subnet_ids = module.network.private_app_subnet_ids
    private_app_security_group_name = module.network.private_app_security_group_name

    data_subnet_ids = module.network.data_subnet_ids
    data_security_group_id = module.network.data_security_group_id
}

