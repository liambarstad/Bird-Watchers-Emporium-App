# Local Deployment Script for Windows PowerShell
# This script allows you to deploy from your laptop

param(
    [string]$Environment = "dev",
    [string]$AWSProfile = "dev",
    [switch]$SkipCloudFormation,
    [switch]$SkipFrontend
)

Write-Host "Starting local deployment for environment: $Environment" -ForegroundColor Green

# Set AWS profile
$env:AWS_PROFILE = $AWSProfile

# Step 1: Deploy Terraform Infrastructure
if (-not $SkipTerraform) {
    Write-Host "Deploying Terraform infrastructure..." -ForegroundColor Yellow
    Set-Location infrastructure/terraform
    
    terraform plan -out=tfplan
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform plan failed"
        exit 1
    }
    
    terraform apply tfplan
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Terraform apply failed"
        exit 1
    }
    
    # Get Terraform outputs
    $vpcId = terraform output -raw vpc_id
    $vpcCidrBlock = terraform output -raw vpc_cidr_block
    $privateSubnetId = terraform output -raw private_subnet_id
    $privateSubnetCidrBlock = terraform output -raw private_subnet_cidr_block
    $awsRegion = terraform output -raw aws_region
    
    Write-Host "Terraform deployment completed" -ForegroundColor Green
    Write-Host "VPC ID: $vpcId" -ForegroundColor Cyan
    Write-Host "Private Subnet ID: $privateSubnetId" -ForegroundColor Cyan
    
    Set-Location ../..
} else {
    Write-Host "Skipping Terraform deployment" -ForegroundColor Yellow
    # Get existing Terraform outputs
    Set-Location infrastructure/terraform
    $vpcId = terraform output -raw vpc_id
    $vpcCidrBlock = terraform output -raw vpc_cidr_block
    $privateSubnetId = terraform output -raw private_subnet_id
    $privateSubnetCidrBlock = terraform output -raw private_subnet_cidr_block
    $awsRegion = terraform output -raw aws_region
    Set-Location ../..
}

# Step 2: Deploy CloudFormation Stack
if (-not $SkipCloudFormation) {
    Write-Host "Deploying CloudFormation stack..." -ForegroundColor Yellow
    Set-Location infrastructure/cloudformation
    
    # Install dependencies
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Error "npm install failed"
        exit 1
    }
    
    # Set environment variables for CDK
    $env:CDK_DEFAULT_ACCOUNT = (aws sts get-caller-identity --query Account --output text)
    $env:CDK_DEFAULT_REGION = $awsRegion

    $env:VPC_ID = $vpcId
    $env:PRIVATE_SUBNET_ID = $privateSubnetId
    $env:VPC_CIDR_BLOCK = $vpcCidrBlock
    $env:PRIVATE_SUBNET_CIDR_BLOCK = $privateSubnetCidrBlock
    
    # Build and deploy
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "CDK build failed"
        exit 1
    }
    
    npx cdk deploy --require-approval never
    if ($LASTEXITCODE -ne 0) {
        Write-Error "CDK deploy failed"
        exit 1
    }
    
    Write-Host "CloudFormation deployment completed" -ForegroundColor Green
    Set-Location ../..
} else {
    Write-Host "Skipping CloudFormation deployment" -ForegroundColor Yellow
}

# Step 3: Build and Deploy Frontend
if (-not $SkipFrontend) {
    Write-Host "Building and deploying frontend..." -ForegroundColor Yellow
    Set-Location frontend
    
    # Install dependencies
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Frontend npm install failed"
        exit 1
    }
    
    # Build frontend
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Frontend build failed"
        exit 1
    }
    
    # Get bucket name from CloudFormation
    $bucketName = aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text
    
    if (-not $bucketName) {
        Write-Error "Could not get bucket name from CloudFormation stack"
        exit 1
    }
    
    # Deploy to S3
    aws s3 sync dist/ s3://$bucketName/ --delete
    if ($LASTEXITCODE -ne 0) {
        Write-Error "S3 sync failed"
        exit 1
    }
    
    # Invalidate CloudFront cache
    $distributionId = aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query 'Stacks[0].Outputs[?OutputKey==`DistributionId`].OutputValue' --output text
    
    if ($distributionId) {
        aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*"
        Write-Host "CloudFront cache invalidated" -ForegroundColor Green
    }
    
    # Get website URL
    $websiteUrl = aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query 'Stacks[0].Outputs[?OutputKey==`WebsiteUrl`].OutputValue' --output text
    
    Write-Host "Frontend deployment completed" -ForegroundColor Green
    Write-Host "Website URL: $websiteUrl" -ForegroundColor Cyan
    
    Set-Location ..
} else {
    Write-Host "Skipping frontend deployment" -ForegroundColor Yellow
}