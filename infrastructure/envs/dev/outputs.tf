output "frontend_certificate_arn" {
    description = "Frontend certificate ARN"
    value       = module.frontend.certificate_arn
}

output "backend_certificate_arn" {
    description = "Backend certificate ARN"
    value       = module.backend.certificate_arn
}

output "frontend_s3_bucket_name" {
    description = "Frontend S3 bucket name"
    value       = module.frontend.s3_bucket_name
}

output "frontend_cloudfront_distribution_id" {
    description = "Frontend CloudFront distribution ID"
    value       = module.frontend.cloudfront_distribution_id
}