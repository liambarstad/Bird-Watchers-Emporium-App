output "api_invoke_url" {
    description = "API Gateway invoke URL"
    value       = aws_apigatewayv2_stage.prod.invoke_url
}

output "ec2_private_ip" {
    description = "Private IP of the EC2 instance"
    value       = aws_instance.backend_box.private_ip
}

output "ec2_public_ip" {
    description = "Public IP of the EC2 instance"
    value       = aws_instance.backend_box.public_ip
}