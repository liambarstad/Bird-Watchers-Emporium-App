param(
    [string]$Environment = "dev",
    [string]$Version = "latest"
)

# Logging function with timestamp
function Write-StageLog {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$Error,
        [switch]$Success,
        [int]$Stage
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = $Message
    
    # Add stage number if provided
    if ($Stage) {
        $formattedMessage = "[Stage $Stage] $formattedMessage"
    }
    
    # Add success/error indicators
    if ($Success) {
        $formattedMessage = "[SUCCESS] $formattedMessage"
        $Color = "Green"
    }
    elseif ($Error) {
        $formattedMessage = "[ERROR] $formattedMessage"
        $Color = "Red"
    }
    
    Write-Host "[$timestamp] $formattedMessage" -ForegroundColor $Color
}

# Helper function to execute commands and exit on failure
function Invoke-CommandOrExit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage,
        [Parameter(Mandatory=$true)]
        [int]$Stage
    )
    
    $result = Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        Write-StageLog "$ErrorMessage (exit code: $LASTEXITCODE)" -Stage $Stage -Error
        exit 1
    }
    return $result
}

# Function to check certificate validation status
function Test-CertificateValidation {
    param(
        [string]$CertificateArn
    )
    
    try {
        $cert = aws acm describe-certificate --certificate-arn $CertificateArn --region $Region --output json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        return $cert.Certificate.Status -eq "ISSUED"
    }
    catch {
        return $false
    }
}

# Function to get certificate validation records
function Get-CertificateValidationRecords {
    param(
        [string]$CertificateArn,
        [string]$Region
    )
    
    try {
        $cert = aws acm describe-certificate --certificate-arn $CertificateArn --region $Region --output json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return $cert.Certificate.DomainValidationOptions
    }
    catch {
        return $null
    }
}


function Test-ECRAuth {
    param(
        [string]$Account,
        [string]$Region, 
        [string]$Repository
    )
    $Registry = "$Account.dkr.ecr.$Region.amazonaws.com"
    $Image = "$($Repository):$($Tag)"
    $FullImage = "$Registry/$($Repository):$($Tag)"

    try {
        $status = curl.exe -s -o NUL -w "%{http_code}" "https://$Registry/v2/"
        return ($status -eq "401")
    } catch {
        return $false
    }
}

$Region = "us-east-1"
$Account = (aws sts get-caller-identity --query "Account" --output text).trim()

Write-StageLog "Starting deployment for Account $Account, Environment $Environment" -Color Green

# Stage 1: Create and Validate Certificates
Write-StageLog "Creating and validating certificates" -Color Yellow -Stage 1
Set-Location "infrastructure/envs/$Environment"

try {
    Invoke-CommandOrExit `
        -Command "terraform init" `
        -ErrorMessage "terraform init failed" `
        -Stage 1
    
    # Create both certificates
    Write-StageLog "Creating ACM certificates for Frontend and Backend" -Color Yellow -Stage 1
    Invoke-CommandOrExit `
        -Command "terraform apply -target='module.frontend.aws_acm_certificate.frontend_certificate' -target='module.backend.aws_acm_certificate.api_certificate' -auto-approve" `
        -ErrorMessage "terraform apply failed" `
        -Stage 1
    
    $FrontendCertificateArn = Invoke-CommandOrExit `
        -Command "terraform output -raw frontend_certificate_arn" `
        -ErrorMessage "Failed to get frontend certificate ARN" `
        -Stage 1
    
    $BackendCertificateArn = Invoke-CommandOrExit `
        -Command "terraform output -raw backend_certificate_arn" `
        -ErrorMessage "Failed to get backend certificate ARN" `
        -Stage 1
    
    if ([string]::IsNullOrEmpty($FrontendCertificateArn)) {
        Write-StageLog "Failed to get Frontend certificate ARN" -Stage 1 -Error
        exit 1
    } 
    Write-StageLog "Frontend certificate created: $FrontendCertificateArn" -Color Cyan -Stage 1

    if ([string]::IsNullOrEmpty($BackendCertificateArn)) {
        Write-StageLog "Failed to get Backend certificate ARN" -Stage 1 -Error
        exit 1
    }
    Write-StageLog "Backend certificate created: $BackendCertificateArn" -Color Cyan -Stage 1
    
    # Check certificate validation status
    Write-StageLog "Checking certificate validation status" -Color Yellow -Stage 1
    
    $FrontendValidated = Test-CertificateValidation -CertificateArn $FrontendCertificateArn
    $BackendValidated = Test-CertificateValidation -CertificateArn $BackendCertificateArn
    
    $UnvalidatedCertificates = @()
    
    if (-not $FrontendValidated) {
        $UnvalidatedCertificates += @{
            Name = "Frontend"
            Arn = $FrontendCertificateArn
        }
    }
    
    if (-not $BackendValidated) {
        $UnvalidatedCertificates += @{
            Name = "Backend"
            Arn = $BackendCertificateArn
        }
    }
    
    if ($UnvalidatedCertificates.Count -eq 0) {
        Write-StageLog "All certificates are validated" -Stage 1 -Success
    }
    else {
        Write-StageLog "Some certificates are not validated" -Color Yellow -Stage 1
        
        foreach ($cert in $UnvalidatedCertificates) {
            Write-StageLog "$($cert.Name) certificate validation records:" -Color Yellow -Stage 1
            
            # Get validation records from AWS
            $ValidationRecords = Get-CertificateValidationRecords -CertificateArn $cert.Arn -Region $Region
            if ($ValidationRecords) {
                foreach ($record in $ValidationRecords) {
                    Write-StageLog "  Name: $($record.ResourceRecord.Name)" -Color Cyan
                    Write-StageLog "  Type: $($record.ResourceRecord.Type)" -Color Cyan
                    Write-StageLog "  Value: $($record.ResourceRecord.Value)" -Color Cyan
                }
            }
        }
        
        Write-StageLog "Add these records to your DNS provider, then run the script again" -Color Red -Stage 1 -Error
        Set-Location "../../.."
        exit 1
    }
}
catch {
    Write-StageLog "Failed to create or validate certificates: $_" -Stage 1 -Error
    exit 1
}

Set-Location "../../.."

# Stage 2: Deploy ECR
Write-StageLog "Creating ECR repository" -Color Yellow -Stage 2
Set-Location "infrastructure/envs/$Environment"

try {
    Invoke-CommandOrExit `
        -Command "terraform init" `
        -ErrorMessage "terraform init failed" `
        -Stage 2
    
    Invoke-CommandOrExit `
        -Command "terraform apply -target='aws_ecr_repository.backend_repo' -target='aws_ecr_lifecycle_policy.backend_policy' -auto-approve" `
        -ErrorMessage "terraform apply failed" `
        -Stage 2

    $ECR_URI = Invoke-CommandOrExit `
        -Command "terraform output -raw ecr_repository_uri" `
        -ErrorMessage "Failed to get ECR repository URI" `
        -Stage 2
    
    Write-StageLog "ECR repository created: $ECR_URI" -Stage 2 -Success
}
catch {
    Write-StageLog "Failed to create ECR repository: $_" -Stage 2 -Error
    exit 1
}

Set-Location "../../.."

# Stage 3: Build and push image
Write-StageLog "Building and pushing Docker image" -Color Yellow -Stage 3
try {
    $Repository = $ECR_URI.split("/")[-1]

    if (-not (Test-ECRAuth -Account $Account -Region $Region -Repository $Repository)) {
        Invoke-CommandOrExit `
            -Command "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $ECR_URI" `
            -ErrorMessage "AWS ECR login failed" `
            -Stage 3
    }

    Set-Location "backend"
    Invoke-CommandOrExit `
        -Command "docker build -t bird-watchers-backend ." `
        -ErrorMessage "Docker build failed" `
        -Stage 3
    
    Invoke-CommandOrExit `
        -Command "docker tag bird-watchers-backend:latest `"$ECR_URI`:$Version`"" `
        -ErrorMessage "Docker tag failed" `
        -Stage 3
    
    Invoke-CommandOrExit `
        -Command "docker tag bird-watchers-backend:latest `"$ECR_URI`:latest`"" `
        -ErrorMessage "Docker tag failed" `
        -Stage 3
    
    Invoke-CommandOrExit `
        -Command "docker push `"$ECR_URI`:$Version`"" `
        -ErrorMessage "Docker push failed" `
        -Stage 3

    Set-Location ".."
    Write-StageLog "Docker image built and pushed successfully" -Stage 3 -Success
}
catch {
    Write-StageLog "Failed to build and push Docker image: $_" -Stage 3 -Error
    exit 1
}

# Stage 4: Deploy EC2 and application
Write-StageLog "Deploying EC2 instance and application" -Color Yellow -Stage 4
Set-Location "infrastructure/envs/$Environment"

try {
    Invoke-CommandOrExit `
        -Command "terraform apply -auto-approve" `
        -ErrorMessage "terraform apply failed" `
        -Stage 4
    
    Write-StageLog "Infrastructure deployed successfully" -Stage 4 -Success
}
catch {
    Write-StageLog "Failed to deploy infrastructure: $_" -Stage 4 -Error
    exit 1
}

Set-Location "../../.."

# Stage 5: Deploy application to EC2
Write-StageLog "Deploying application to EC2..." -Color Yellow -Stage 5
try {
    # Get EC2 instance IP from Terraform output
    $EC2_IP = Invoke-CommandOrExit `
        -Command "terraform output -raw ec2_public_ip" `
        -ErrorMessage "Failed to get EC2 instance IP" `
        -Stage 5
    
    if ([string]::IsNullOrEmpty($EC2_IP)) {
        Write-StageLog "Could not get EC2 instance IP" -Stage 5 -Error
        exit 1
    }

    # SSH into instance and pull latest image
    $SSHCommand = @"
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $RegistryName

docker stop bird-watchers-backend || true
docker rm bird-watchers-backend || true

docker pull $ECR_URI`:latest

systemctl restart bird-watchers-backend.service

sleep 5
if docker ps | grep -q bird-watchers-backend; then
    echo "Backend container is running"
    docker logs --tail 20 bird-watchers-backend
else
    echo "Failed to start backend container"
    docker logs bird-watchers-backend || true
    exit 1
fi
"@

    # Execute SSH command
    Invoke-CommandOrExit `
        -Command "ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP `"$SSHCommand`"" `
        -ErrorMessage "SSH deployment failed" `
        -Stage 5

    Write-StageLog "Application deployed to EC2 successfully" -Stage 5 -Success
}
catch {
    Write-StageLog "Failed to deploy application to EC2: $_" -Stage 5 -Error
    exit 1
}

# Stage 6: Build and Deploy Frontend
Write-StageLog "Building and deploying frontend" -Color Yellow -Stage 6
try {
    # Get frontend resources from Terraform output
    $FrontendS3Bucket = Invoke-CommandOrExit `
        -Command "terraform output -raw frontend_s3_bucket_name" `
        -ErrorMessage "Failed to get frontend S3 bucket name" `
        -Stage 6
    
    $CloudFrontDistributionId = Invoke-CommandOrExit `
        -Command "terraform output -raw frontend_cloudfront_distribution_id" `
        -ErrorMessage "Failed to get CloudFront distribution ID" `
        -Stage 6
    
    if ([string]::IsNullOrEmpty($FrontendS3Bucket) -or [string]::IsNullOrEmpty($CloudFrontDistributionId)) {
        Write-StageLog "Could not get frontend S3 bucket or CloudFront distribution ID" -Stage 6 -Error
        exit 1
    }
    
    Write-StageLog "Frontend S3 bucket: $FrontendS3Bucket" -Color Cyan -Stage 6
    Write-StageLog "CloudFront distribution: $CloudFrontDistributionId" -Color Cyan -Stage 6
    
    # Build frontend
    Write-StageLog "Building frontend" -Color Yellow -Stage 6
    Set-Location "./frontend"
    Invoke-CommandOrExit `
        -Command "npm run build" `
        -ErrorMessage "npm run build failed" `
        -Stage 6
    
    if (-not (Test-Path "dist")) {
        Write-StageLog "Frontend build failed - dist directory not found" -Stage 6 -Error
        exit 1
    }
    
    # Sync to S3
    Write-StageLog "Syncing frontend to S3..." -Color Yellow -Stage 6
    Invoke-CommandOrExit `
        -Command "aws s3 sync dist/ s3://$FrontendS3Bucket --delete" `
        -ErrorMessage "AWS S3 sync failed" `
        -Stage 6
    
    # Create CloudFront invalidation
    Write-StageLog "Creating CloudFront invalidation..." -Color Yellow -Stage 6
    $InvalidationResult = Invoke-CommandOrExit `
        -Command "aws cloudfront create-invalidation --distribution-id $CloudFrontDistributionId --paths '/*' --output json | ConvertFrom-Json" `
        -ErrorMessage "AWS CloudFront invalidation failed" `
        -Stage 6
    
    Write-StageLog "CloudFront invalidation created: $($InvalidationResult.Invalidation.Id)" -Color Cyan -Stage 6
    Write-StageLog "Frontend deployed successfully" -Stage 6 -Success
    
    Set-Location ".."
}
catch {
    Write-StageLog "Failed to deploy frontend: $_" -Stage 6 -Error
    exit 1
}

Write-StageLog "Full deployment completed successfully!" -Color Green
Write-StageLog "   Environment: $Environment" -Color Cyan
Write-StageLog "   Version: $Version" -Color Cyan
Write-StageLog "   ECR URI: $ECR_URI" -Color Cyan
Write-StageLog "   Frontend S3: $FrontendS3Bucket" -Color Cyan
Write-StageLog "   CloudFront: $CloudFrontDistributionId" -Color Cyan
