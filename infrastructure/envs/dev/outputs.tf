output "frontend_certificate_arn" {
    description = "Frontend certificate ARN"
    value       = module.frontend.certificate_arn
}

output "backend_certificate_arn" {
    description = "Backend certificate ARN"
    value       = module.backend.certificate_arn
}
