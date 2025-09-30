output "api_invoke_url" {
    description = "API Gateway invoke URL"
    value       = aws_apigatewayv2_stage.prod.invoke_url
}

output "api_custom_domain_url" {
    description = "API Gateway custom domain URL"
    value       = "https://${aws_apigatewayv2_domain_name.api_domain.domain_name}"
}

output "dns_target_domain" {
    description = "Target domain name for DNS CNAME record (add this to Google Domains)"
    value       = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].target_domain_name
}

output "dns_hosted_zone_id" {
    description = "Hosted zone ID for DNS record (for reference)"
    value       = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].hosted_zone_id
}

output "ec2_private_ip" {
    description = "Private IP of the EC2 instance"
    value       = aws_instance.backend_box.private_ip
}

output "ec2_public_ip" {
    description = "Public IP of the EC2 instance"
    value       = aws_instance.backend_box.public_ip
}

output "ecr_repository_uri" {
    description = "ECR repository URI for the backend"
    value       = aws_ecr_repository.backend_repo.repository_url
}

output "certificate_arn" {
    description = "ACM certificate ARN for the API Gateway domain"
    value       = aws_acm_certificate.api_certificate.arn
}

output "certificate_validation_records" {
    description = "Certificate validation DNS records to add to Google Domains"
    value = {
        for dvo in aws_acm_certificate.api_certificate.domain_validation_options : dvo.domain_name => {
            name   = dvo.resource_record_name
            record = dvo.resource_record_value
            type   = dvo.resource_record_type
        }
    }
}