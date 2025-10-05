terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
        random = {
            source  = "hashicorp/random"
            version = "~> 3.1"
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
        Env = var.environment
        Project = "BWE"
    }
}

resource "aws_acm_certificate_validation" "frontend_certificate" {
    certificate_arn = aws_acm_certificate.frontend_certificate.arn
}

// ------------- Frontend Bucket Setup ---------------

resource "random_id" "bucket_suffix" {
    byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
    bucket = "bwe-frontend-${var.environment}-${random_id.bucket_suffix.hex}"
    force_destroy = true

    tags = {
        Name        = "bwe-frontend-${var.environment}"
        Environment = var.environment
        Project = "BWE"
    }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_pab" {
    bucket = aws_s3_bucket.frontend_bucket.id

    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
    bucket = aws_s3_bucket.frontend_bucket.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid       = "AllowCloudFrontServicePrincipal"
                Effect    = "Allow"
                Principal = {
                    Service = "cloudfront.amazonaws.com"
                }
                Action   = "s3:GetObject"
                Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
                Condition = {
                    StringEquals = {
                        "AWS:SourceArn" = aws_cloudfront_distribution.frontend_distribution.arn
                    }
                }
            }
        ]
    })

    depends_on = [aws_cloudfront_distribution.frontend_distribution]
}

resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
    bucket = aws_s3_bucket.frontend_bucket.id

    index_document {
        suffix = "index.html"
    }

    error_document {
        key = "error.html"
    }
}

// ------------- CloudFront Distribution Setup ---------------

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
    name                              = "bwe-frontend-oac-${var.environment}"
    description                       = "OAC for BWE Frontend"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
    origin {
        domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
        origin_id                = "S3-${aws_s3_bucket.frontend_bucket.bucket}"
    }

    enabled             = true
    is_ipv6_enabled     = true
    comment             = "BWE Frontend Distribution - ${var.environment}"
    default_root_object = "index.html"

    aliases = [local.frontend_domain_name]

    viewer_certificate {
        acm_certificate_arn      = aws_acm_certificate_validation.frontend_certificate.certificate_arn
        ssl_support_method       = "sni-only"
        minimum_protocol_version = "TLSv1.2_2021"
    }

    default_cache_behavior {
        allowed_methods  = ["GET", "HEAD"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }

        viewer_protocol_policy = "redirect-to-https"
        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
    }

    ordered_cache_behavior {
        path_pattern     = "/assets/*"
        allowed_methods  = ["GET", "HEAD"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }

        viewer_protocol_policy = "redirect-to-https"
        min_ttl                = 0
        default_ttl            = 86400
        max_ttl                = 31536000
    }

    restrictions {
        geo_restriction {
            restriction_type = "whitelist"
            locations = [
                # North America
                "US", "CA",
                # Asia
                "JP", "KR", "IL",
                # Europe (excluding Ukraine, Belarus, Russia)
                "AD", "AL", "AT", "BA", "BE", "BG", "CH", "CY", "CZ", "DE", "DK", 
                "EE", "ES", "FI", "FR", "GB", "GR", "HR", "HU", "IE", "IS", "IT", 
                "LI", "LT", "LU", "LV", "MC", "MD", "ME", "MK", "MT", "NL", "NO", 
                "PL", "PT", "RO", "RS", "SE", "SI", "SK", "SM", "VA"
            ]
        }
    }

    tags = {
        Name        = "bwe-frontend-distribution-${var.environment}"
        Env = var.environment
        Project = "BWE"
    }
}