variable "api_id" {
    description = "API Gateway ID"
    type        = string
}

variable "route_path" {
    description = "The route path (e.g., /query, /conversations)"
    type        = string
}

variable "http_method" {
    description = "HTTP method for the route (e.g., POST, GET, PUT, DELETE)"
    type        = string
    default     = "POST"
}

variable "integration_type" {
    description = "Integration type (HTTP_PROXY, AWS_PROXY, MOCK, etc.)"
    type        = string
    default     = "HTTP_PROXY"
}

variable "integration_method" {
    description = "Integration method (POST, GET, ANY, etc.)"
    type        = string
    default     = "POST"
}

variable "integration_uri" {
    description = "Integration URI (backend service URL)"
    type        = string
}

variable "request_parameters" {
    description = "Request parameters for the integration"
    type        = map(string)
    default     = {}
}

# CORS Configuration
variable "cors_origin" {
    description = "Allowed CORS origin"
    type        = string
    default     = "*"
}

variable "cors_allow_methods" {
    description = "Allowed HTTP methods for CORS"
    type        = list(string)
    default     = ["POST", "OPTIONS"]
}

variable "cors_allow_headers" {
    description = "Allowed headers for CORS"
    type        = list(string)
    default     = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]
}

variable "cors_max_age" {
    description = "CORS max age in seconds"
    type        = string
    default     = "600"
}
