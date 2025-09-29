param(
    [string]$Environment = "dev",
    [string]$Version = "latest"
)

Write-Host "🚀 Starting full deployment for $Environment" -ForegroundColor Green

# Stage 1: Deploy ECR
Write-Host "📦 Stage 1: Creating ECR repository..." -ForegroundColor Yellow
Set-Location "infrastructure/envs/$Environment"

try {
    terraform apply -target=aws_ecr_repository.backend_repo -target=aws_ecr_lifecycle_policy.backend_policy -auto-approve
    $ECR_URI = terraform output -raw ecr_repository_uri
    Write-Host "✅ ECR repository created: $ECR_URI" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to create ECR repository: $_" -ForegroundColor Red
    exit 1
}

Set-Location "../../.."

# Stage 2: Build and push image
Write-Host "🐳 Stage 2: Building and pushing Docker image..." -ForegroundColor Yellow
try {
    & "./scripts/build-and-push.sh" $Environment $Version
    Write-Host "✅ Docker image built and pushed successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to build and push Docker image: $_" -ForegroundColor Red
    exit 1
}

# Stage 3: Deploy EC2 and application
Write-Host "🖥️  Stage 3: Deploying EC2 instance and application..." -ForegroundColor Yellow
Set-Location "infrastructure/envs/$Environment"

try {
    terraform apply -auto-approve
    Write-Host "✅ Infrastructure deployed successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to deploy infrastructure: $_" -ForegroundColor Red
    exit 1
}

Set-Location "../../.."

# Stage 4: Deploy application to EC2
Write-Host "🚀 Stage 4: Deploying application to EC2..." -ForegroundColor Yellow
try {
    & "./scripts/deploy-to-ec2.sh" $Environment
    Write-Host "✅ Application deployed to EC2 successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to deploy application to EC2: $_" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Full deployment completed successfully!" -ForegroundColor Green
Write-Host "   Environment: $Environment" -ForegroundColor Cyan
Write-Host "   Version: $Version" -ForegroundColor Cyan
Write-Host "   ECR URI: $ECR_URI" -ForegroundColor Cyan
