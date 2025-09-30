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
