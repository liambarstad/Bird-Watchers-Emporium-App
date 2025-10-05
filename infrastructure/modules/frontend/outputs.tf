output "certificate_arn" {
    description = "ACM certificate ARN for the frontend domain"
    value       = aws_acm_certificate.frontend_certificate.arn
}

output "certificate_validation_records" {
    description = "Certificate validation DNS records to add to Google Domains"
    value = {
        for dvo in aws_acm_certificate.frontend_certificate.domain_validation_options : dvo.domain_name => {
            name   = dvo.resource_record_name
            record = dvo.resource_record_value
            type   = dvo.resource_record_type
        }
    }
}

output "s3_bucket_name" {
    description = "Name of the S3 bucket for frontend hosting"
    value       = aws_s3_bucket.frontend_bucket.bucket
}

output "s3_bucket_arn" {
    description = "ARN of the S3 bucket for frontend hosting"
    value       = aws_s3_bucket.frontend_bucket.arn
}

output "cloudfront_distribution_id" {
    description = "ID of the CloudFront distribution"
    value       = aws_cloudfront_distribution.frontend_distribution.id
}

output "cloudfront_distribution_arn" {
    description = "ARN of the CloudFront distribution"
    value       = aws_cloudfront_distribution.frontend_distribution.arn
}

output "cloudfront_domain_name" {
    description = "Domain name of the CloudFront distribution"
    value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}

output "cloudfront_hosted_zone_id" {
    description = "CloudFront hosted zone ID for DNS configuration"
    value       = aws_cloudfront_distribution.frontend_distribution.hosted_zone_id
}