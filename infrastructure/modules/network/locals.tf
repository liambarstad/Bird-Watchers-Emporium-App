locals {
    resource_tag       = "bwe-${var.environment}"
    azs                = slice(data.aws_availability_zones.azs.names, 0, var.az_count)
    public_cidrs       = [for i in range(var.az_count) : cidrsubnet(var.cidr_block, 8, i)]
    private_app_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.cidr_block, 8, i + 100)]
    private_data_cidrs = [for i in range(var.az_count) : cidrsubnet(var.cidr_block, 8, i + 200)]
}