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

// ------------- Certificate Setup ---------------

resource "aws_acm_certificate" "frontend_certificate" {
    domain_name       = local.frontend_domain_name
    validation_method = "DNS"

    lifecycle {
        create_before_destroy = true
    }

    tags = {
        Name = "bwe-frontend-certificate-${var.environment}"
    }
}

resource "aws_acm_certificate_validation" "frontend_certificate" {
    certificate_arn = aws_acm_certificate.frontend_certificate.arn
}