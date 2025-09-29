locals {
    aws_region  = "us-east-1"
    environment = "dev"
}

module "network" {
    source      = "../../modules/network"
    aws_region  = local.aws_region
    environment = local.environment
    cidr_block  = "10.0.0.0/16"
    az_count    = 1 
}

module "backend" {
    source      = "../../modules/backend"
    aws_region  = local.aws_region
    environment = local.environment
    instance_type = "g5.xlarge"
}

/*module "frontend" {
    source = "../../modules/frontend"
    # pass API url to inject into site build or CF header if needed
    api_base_url = module.backend.api_invoke_url
}*/