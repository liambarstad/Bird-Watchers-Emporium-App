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

// ------------- Define API Gateway ---------------

resource "api_gatewayv2_api" "api" {
    name          = "${local.resource_tag}-api"
    description   = "Bird Watchers Emporium ${var.environment} API"
    protocol_type = "HTTP"
    version       = "1.0.0"
}

resource "aws_apigatewayv2_stage" "prod" {
    api_id      = aws_apigatewayv2_api.api.id
    name        = "$default"
    auto_deploy = true
}

// ------------- Custom Domain Setup ---------------

# ACM Certificate for the custom domain
resource "aws_acm_certificate" "api_certificate" {
    domain_name       = local.backend_domain_name
    validation_method = "DNS"

    lifecycle {
        create_before_destroy = true
    }

    tags = {
        Name = "bwe-api-certificate-${var.environment}"
    }
}

# Certificate validation (manual DNS records required)
resource "aws_acm_certificate_validation" "api_certificate" {
    certificate_arn = aws_acm_certificate.api_certificate.arn
}

# API Gateway Domain Name
resource "aws_apigatewayv2_domain_name" "api_domain" {
    domain_name = local.backend_domain_name
    domain_name_configuration {
        certificate_arn = aws_acm_certificate_validation.api_certificate.certificate_arn
        endpoint_type   = "REGIONAL"
        security_policy = "TLS_1_2"
    }
}

# API Gateway Domain Mapping
resource "aws_apigatewayv2_api_mapping" "api_mapping" {
    api_id      = aws_apigatewayv2_api.api.id
    domain_name = aws_apigatewayv2_domain_name.api_domain.id
    stage       = aws_apigatewayv2_stage.prod.id
}

// ------------- EC2 Instance Setup ---------------

resource "aws_iam_role" "backend_role" {
    name               = "bwe-backend-role-${var.environment}"
    assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
    role       = aws_iam_role.backend_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ECR permissions for the EC2 instance
resource "aws_iam_role_policy" "ecr_policy" {
    name = "bwe-backend-ecr-policy-${var.environment}"
    role = aws_iam_role.backend_role.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "ecr:GetAuthorizationToken",
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "ecr:DescribeRepositories",
                    "ecr:DescribeImages"
                ]
                Resource = aws_ecr_repository.backend_repo.arn
            }
        ]
    })
}

resource "aws_iam_instance_profile" "backend_instance_profile" {
    name = "bwe-backend-instance-profile-${var.environment}"
    role = aws_iam_role.backend_role.name
}

resource "aws_instance" "backend_box" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    subnet_id = var.data_subnet_ids[0]
    security_groups = [var.data_security_group_name]
    iam_instance_profile = aws_iam_instance_profile.backend_instance_profile.name

    user_data = base64encode(templatefile("${path.module}/user-data.sh", {
        ecr_repository_uri = var.ecr_repository_uri
        backend_port      = var.backend_port
        environment       = var.environment
        aws_region        = var.aws_region
    }))

    tags = {
        Name = "bwe-backend-${var.environment}"
    }
}

// ------------- Attach API Gateway to EC2 Instance on /query ---------------

module "query_route" {
    source = "./api-route"
    
    api_id             = aws_apigatewayv2_api.api.id
    route_path         = "/query"
    http_method        = "POST"
    integration_type   = "HTTP_PROXY"
    integration_method = "POST"
    integration_uri    = "http://${aws_instance.backend_box.private_ip}:${var.backend_port}/query"
    
    cors_origin        = var.frontend_base_url
    cors_allow_methods = ["POST", "OPTIONS"]
    cors_allow_headers = [
        "Content-Type",
        "X-Amz-Date", 
        "Authorization",
        "X-Api-Key",
        "X-Amz-Security-Token"
    ]
    
    request_parameters = {
        "overwrite:path" = "/query"
    }
}