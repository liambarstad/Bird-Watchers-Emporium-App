terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

# API Gateway Integration for the route
resource "aws_apigatewayv2_integration" "route_integration" {
    api_id           = var.api_id
    integration_type = var.integration_type
    integration_method = var.integration_method
    integration_uri  = var.integration_uri
    
    # Optional request parameters for path rewriting
    dynamic "request_parameters" {
        for_each = var.request_parameters
        content {
            request_parameter_key   = request_parameters.key
            request_parameter_value = request_parameters.value
        }
    }
}

# Main route for the HTTP method
resource "aws_apigatewayv2_route" "main_route" {
    api_id    = var.api_id
    route_key = "${var.http_method} ${var.route_path}"
    target    = "integrations/${aws_apigatewayv2_integration.route_integration.id}"
}

# CORS preflight route for OPTIONS requests
resource "aws_apigatewayv2_route" "cors_options" {
    api_id    = var.api_id
    route_key = "OPTIONS ${var.route_path}"
    target    = "integrations/${aws_apigatewayv2_integration.cors_integration.id}"
}

# CORS integration for preflight requests
resource "aws_apigatewayv2_integration" "cors_integration" {
    api_id           = var.api_id
    integration_type = "MOCK"
    
    integration_response_selection_expression = "200"
    
    request_templates = {
        "application/json" = "{\"statusCode\": 200}"
    }
}

# CORS response for preflight
resource "aws_apigatewayv2_integration_response" "cors_response" {
    api_id                   = var.api_id
    integration_id           = aws_apigatewayv2_integration.cors_integration.id
    integration_response_key = "200"
    
    response_templates = {
        "application/json" = jsonencode({
            statusCode = 200
            headers = {
                "Access-Control-Allow-Headers" = join(",", var.cors_allow_headers)
                "Access-Control-Allow-Methods" = join(",", var.cors_allow_methods)
                "Access-Control-Allow-Origin"  = var.cors_origin
                "Access-Control-Max-Age"        = var.cors_max_age
            }
        })
    }
}

# Method response for CORS preflight
resource "aws_apigatewayv2_route_response" "cors_method_response" {
    api_id             = var.api_id
    route_id           = aws_apigatewayv2_route.cors_options.id
    route_response_key = "200"
}

# Response for the actual request with CORS headers
resource "aws_apigatewayv2_integration_response" "main_response" {
    api_id                   = var.api_id
    integration_id           = aws_apigatewayv2_integration.route_integration.id
    integration_response_key = "200"
    
    response_templates = {
        "application/json" = jsonencode({
            statusCode = 200
            headers = {
                "Access-Control-Allow-Origin"  = var.cors_origin
                "Access-Control-Allow-Methods" = join(",", var.cors_allow_methods)
                "Access-Control-Allow-Headers" = join(",", var.cors_allow_headers)
            }
        })
    }
}

# Method response for the main route
resource "aws_apigatewayv2_route_response" "main_method_response" {
    api_id             = var.api_id
    route_id           = aws_apigatewayv2_route.main_route.id
    route_response_key = "200"
}
