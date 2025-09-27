#!/bin/bash

# Local Deployment Script for Unix/Linux/macOS
# This script allows you to deploy from your laptop

set -e

# Default values
ENVIRONMENT=${1:-"dev"}
AWS_PROFILE=${2:-"dev"}
SKIP_TERRAFORM=${SKIP_TERRAFORM:-false}
SKIP_CLOUDFORMATION=${SKIP_CLOUDFORMATION:-false}
SKIP_FRONTEND=${SKIP_FRONTEND:-false}

echo "🚀 Starting local deployment for environment: $ENVIRONMENT"

# Set AWS profile
export AWS_PROFILE=$AWS_PROFILE

# Step 1: Deploy Terraform Infrastructure
if [ "$SKIP_TERRAFORM" != "true" ]; then
    echo "📋 Deploying Terraform infrastructure..."
    cd infrastructure/terraform
    
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan
    
    # Get Terraform outputs
    VPC_ID=$(terraform output -raw vpc_id)
    PRIVATE_SUBNET_ID=$(terraform output -raw private_subnet_id)
    VPC_CIDR_BLOCK=$(terraform output -raw vpc_cidr_block)
    PRIVATE_SUBNET_CIDR_BLOCK=$(terraform output -raw private_subnet_cidr_block)
    AWS_REGION=$(terraform output -raw aws_region)
    
    echo "✅ Terraform deployment completed"
    echo "VPC ID: $VPC_ID"
    echo "Private Subnet ID: $PRIVATE_SUBNET_ID"
    
    cd ../..
else
    echo "⏭️ Skipping Terraform deployment"
    # Get existing Terraform outputs
    cd infrastructure/terraform
    VPC_ID=$(terraform output -raw vpc_id)
    PRIVATE_SUBNET_ID=$(terraform output -raw private_subnet_id)
    VPC_CIDR_BLOCK=$(terraform output -raw vpc_cidr_block)
    PRIVATE_SUBNET_CIDR_BLOCK=$(terraform output -raw private_subnet_cidr_block)
    AWS_REGION=$(terraform output -raw aws_region)
    cd ../..
fi

# Step 2: Deploy CloudFormation Stack
if [ "$SKIP_CLOUDFORMATION" != "true" ]; then
    echo "☁️ Deploying CloudFormation stack..."
    cd infrastructure/cloudformation
    
    # Install dependencies
    npm install
    
    # Set environment variables for CDK
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEFAULT_REGION=$AWS_REGION
    export VPC_ID=$VPC_ID
    export PRIVATE_SUBNET_ID=$PRIVATE_SUBNET_ID
    export VPC_CIDR_BLOCK=$VPC_CIDR_BLOCK
    export PRIVATE_SUBNET_CIDR_BLOCK=$PRIVATE_SUBNET_CIDR_BLOCK
    
    # Build and deploy
    npm run build
    npx cdk deploy --require-approval never
    
    echo "✅ CloudFormation deployment completed"
    cd ../..
else
    echo "⏭️ Skipping CloudFormation deployment"
fi

# Step 3: Build and Deploy Frontend
if [ "$SKIP_FRONTEND" != "true" ]; then
    echo "🎨 Building and deploying frontend..."
    cd frontend
    
    # Install dependencies
    npm install
    
    # Build frontend
    npm run build
    
    # Get bucket name from CloudFormation
    BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text)
    
    if [ -z "$BUCKET_NAME" ]; then
        echo "❌ Could not get bucket name from CloudFormation stack"
        exit 1
    fi
    
    # Deploy to S3
    aws s3 sync dist/ s3://$BUCKET_NAME/ --delete
    
    # Invalidate CloudFront cache
    DISTRIBUTION_ID=$(aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query 'Stacks[0].Outputs[?OutputKey==`DistributionId`].OutputValue' --output text)
    
    if [ -n "$DISTRIBUTION_ID" ]; then
        aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
        echo "✅ CloudFront cache invalidated"
    fi
    
    # Get website URL
    WEBSITE_URL=$(aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack --query 'Stacks[0].Outputs[?OutputKey==`WebsiteUrl`].OutputValue' --output text)
    
    echo "✅ Frontend deployment completed"
    echo "🌐 Website URL: $WEBSITE_URL"
    
    cd ..
else
    echo "⏭️ Skipping frontend deployment"
fi

echo "🎉 Deployment completed successfully!"
