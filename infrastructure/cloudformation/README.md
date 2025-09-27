# Bird Watchers' Emporium - Frontend Infrastructure

This directory contains the CloudFormation infrastructure code for deploying the Bird Watchers' Emporium frontend to AWS using S3 and CloudFront.

## Architecture

- **S3 Bucket**: Hosts the static React frontend files
- **CloudFront Distribution**: Provides global CDN with HTTPS
- **Origin Access Control (OAC)**: Secure access from CloudFront to S3
- **Custom Error Pages**: Handles SPA routing (404/403 → index.html)

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Node.js** (v18 or later)
3. **AWS CDK** installed globally: `npm install -g aws-cdk`
4. **Terraform** infrastructure deployed (VPC, subnets)

## Setup

1. **Install dependencies**:
   ```bash
   cd infrastructure/cloudformation
   npm install
   ```

2. **Configure AWS credentials**:
   ```bash
   aws configure
   # or use AWS_PROFILE environment variable
   export AWS_PROFILE=dev
   ```

3. **Bootstrap CDK** (first time only):
   ```bash
   cdk bootstrap
   ```

## Deployment

### Deploy Infrastructure Only
```bash
npm run deploy:infrastructure
```

### Deploy Frontend Only (after infrastructure exists)
```bash
npm run deploy:frontend
```

### Deploy Everything
```bash
npm run deploy:all
```

## Environment Variables

You can customize the deployment using these environment variables:

- `AWS_REGION`: AWS region (default: us-east-1)
- `BUCKET_NAME`: S3 bucket name (default: auto-generated)
- `CDK_DEFAULT_ACCOUNT`: AWS account ID
- `CDK_DEFAULT_REGION`: AWS region

## Stack Outputs

After deployment, the stack provides these outputs:

- `BucketName`: S3 bucket name
- `BucketArn`: S3 bucket ARN
- `DistributionId`: CloudFront distribution ID
- `DistributionDomainName`: CloudFront domain name
- `WebsiteUrl`: Full website URL

## File Structure

```
infrastructure/cloudformation/
├── src/
│   ├── app.ts              # CDK app entry point
│   ├── s3-stack.ts         # S3 and CloudFront stack
│   └── index.ts            # Exports
├── scripts/
│   ├── deploy.js           # Full deployment script
│   ├── deploy-frontend.js  # Frontend-only deployment
│   └── s3-deploy.js        # Advanced S3 deployment with cache invalidation
├── package.json            # Dependencies and scripts
├── tsconfig.json          # TypeScript configuration
├── cdk.json               # CDK configuration
└── README.md              # This file
```

## Features

- **Automatic S3 sync**: Uploads built frontend files
- **Cache invalidation**: Clears CloudFront cache after deployment
- **SPA support**: Handles React Router with proper error pages
- **Security**: Private S3 bucket with OAC
- **Performance**: Optimized caching policies
- **Cleanup**: Removes old files during deployment

## Troubleshooting

### Common Issues

1. **CDK Bootstrap Required**:
   ```bash
   cdk bootstrap aws://ACCOUNT-ID/REGION
   ```

2. **Permissions Error**:
   - Ensure your AWS credentials have sufficient permissions
   - Required permissions: S3, CloudFront, CloudFormation, IAM

3. **Bucket Name Conflicts**:
   - S3 bucket names must be globally unique
   - Use environment variable `BUCKET_NAME` to specify a custom name

4. **Build Errors**:
   - Ensure the frontend builds successfully first
   - Run `npm run build` in the frontend directory

### Useful Commands

```bash
# View stack outputs
aws cloudformation describe-stacks --stack-name BirdWatchersEmporiumFrontendStack

# Check CloudFront distribution status
aws cloudfront get-distribution --id DISTRIBUTION-ID

# List S3 bucket contents
aws s3 ls s3://BUCKET-NAME --recursive

# Create CloudFront invalidation manually
aws cloudfront create-invalidation --distribution-id DISTRIBUTION-ID --paths "/*"
```

## Integration with Terraform

This CloudFormation stack is designed to work alongside the Terraform infrastructure:

- Terraform manages: VPC, subnets, networking
- CloudFormation manages: S3, CloudFront, application resources

The stacks are independent but can reference each other's outputs if needed.
