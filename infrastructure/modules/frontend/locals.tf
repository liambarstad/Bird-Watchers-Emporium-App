locals {
    frontend_domain_name = replace(replace(var.frontend_base_url, "https://", ""), "http://", "")
}