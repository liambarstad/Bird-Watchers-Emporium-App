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
        $formattedMessage = "$formattedMessage [SUCCESS]"
        $Color = "Green"
    }
    elseif ($Error) {
        $formattedMessage = "$formattedMessage [ERROR]"
        $Color = "Red"
    }
    
    Write-Host "[$timestamp] $formattedMessage" -ForegroundColor $Color
}

# Function to check certificate validation status
function Test-CertificateValidation {
    param(
        [string]$CertificateArn
    )
    
    try {
        $cert = aws acm describe-certificate --certificate-arn $CertificateArn --region us-east-1 --output json | ConvertFrom-Json
        return $cert.Certificate.Status -eq "ISSUED"
    }
    catch {
        return $false
    }
}

# Function to get certificate validation records
function Get-CertificateValidationRecords {
    param(
        [string]$CertificateArn
    )
    
    try {
        $cert = aws acm describe-certificate --certificate-arn $CertificateArn --region us-east-1 --output json | ConvertFrom-Json
        return $cert.Certificate.DomainValidationOptions
    }
    catch {
        return $null
    }
}

Write-StageLog "Starting deployment for $Environment" -Color Green

# Stage 1: Create and Validate Certificates
Write-StageLog "Creating and validating certificates" -Color Yellow -Stage 1
Set-Location "infrastructure/envs/$Environment"

try {
    # Create both certificates
    Write-StageLog "Creating ACM certificates for Frontend and Backend" -Color Yellow -Stage 1
    terraform apply -target=aws_acm_certificate.frontend_certificate -target=aws_acm_certificate.api_certificate -auto-approve
    
    $FrontendCertificateArn = terraform output -raw frontend_certificate_arn
    $BackendCertificateArn = terraform output -raw backend_certificate_arn
    
    if ([string]::IsNullOrEmpty($FrontendCertificateArn)) {
        Write-StageLog "Failed to get Frontend certificate ARN" -Stage 1 -Error
        exit 1
    } 
    Write-StageLog "Frontend certificate created: $FrontendCertificateArn" -Color Cyan -Stage 1

    if (-or [string]::IsNullOrEmpty($BackendCertificateArn)) {
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
            $ValidationRecords = Get-CertificateValidationRecords -CertificateArn $cert.Arn
            if ($ValidationRecords) {
                foreach ($record in $ValidationRecords) {
                    Write-StageLog "  Name: $($record.ResourceRecord.Name)" -Color Cyan
                    Write-StageLog "  Type: $($record.ResourceRecord.Type)" -Color Cyan
                    Write-StageLog "  Value: $($record.ResourceRecord.Value)" -Color Cyan
                }
            }
        }
        
        Write-StageLog "Add these DNS records to Google Domains, then run the script again" -Color Red -Stage 1 -Error
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
    terraform apply -target=aws_ecr_repository.backend_repo -target=aws_ecr_lifecycle_policy.backend_policy -auto-approve
    $ECR_URI = terraform output -raw ecr_repository_uri
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
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URI

    Set-Location "backend"
    docker build -t bird-watchers-backend .

    docker tag bird-watchers-backend:latest "$ECR_URI`:$Version"
    docker tag bird-watchers-backend:latest "$ECR_URI`:latest"

    docker push "$ECR_URI`:$Version"
    docker push "$ECR_URI`:latest"

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
    terraform apply -auto-approve
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
    $EC2_IP = terraform output -raw ec2_public_ip
    if ([string]::IsNullOrEmpty($EC2_IP)) {
        Write-StageLog "Could not get EC2 instance IP" -Stage 5 -Error
        exit 1
    }

    # SSH into instance and pull latest image
    $SSHCommand = @"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URI

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
    ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP $SSHCommand

    Write-StageLog "Application deployed to EC2 successfully" -Stage 5 -Success
}
catch {
    Write-StageLog "Failed to deploy application to EC2: $_" -Stage 5 -Error
    exit 1
}

Write-StageLog "Full deployment completed successfully!" -Color Green
Write-StageLog "   Environment: $Environment" -Color Cyan
Write-StageLog "   Version: $Version" -Color Cyan
Write-StageLog "   ECR URI: $ECR_URI" -Color Cyan
