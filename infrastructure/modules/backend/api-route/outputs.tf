output "route_id" {
    description = "ID of the main route"
    value       = aws_apigatewayv2_route.main_route.id
}

output "integration_id" {
    description = "ID of the route integration"
    value       = aws_apigatewayv2_integration.route_integration.id
}

output "cors_route_id" {
    description = "ID of the CORS OPTIONS route"
    value       = aws_apigatewayv2_route.cors_options.id
}
