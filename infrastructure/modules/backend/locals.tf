locals {
    resource_tag = "bwe-${var.environment}"
    backend_domain_name = replace(replace(var.backend_base_url, "https://", ""), "http://", "")
}