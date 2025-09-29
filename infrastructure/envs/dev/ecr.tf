# ECR Repository for backend images
resource "aws_ecr_repository" "backend_repo" {
    name                 = "bwe-backend-${local.environment}"
    image_tag_mutability = "MUTABLE"
    
    image_scanning_configuration {
        scan_on_push = true
    }
}

# ECR lifecycle policy
resource "aws_ecr_lifecycle_policy" "backend_policy" {
    repository = aws_ecr_repository.backend_repo.name
    
    policy = jsonencode({
        rules = [{
            rulePriority = 1
            description  = "Keep last 10 images"
            selection = {
                tagStatus     = "tagged"
                tagPrefixList = ["v"]
                countType     = "imageCountMoreThan"
                countNumber   = 10
            }
            action = {
                type = "expire"
            }
        }]
    })
}

# Output ECR repository URI
output "ecr_repository_uri" {
    description = "ECR repository URI for the backend"
    value       = aws_ecr_repository.backend_repo.repository_url
}
