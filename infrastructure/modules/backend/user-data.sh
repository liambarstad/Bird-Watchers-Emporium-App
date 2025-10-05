#!/bin/bash
set -e

# Update system and install Docker
apt-get update
apt-get install -y docker.io awscli curl

# Install and configure SSM Agent
systemctl enable snapd
systemctl start snapd
snap install amazon-ssm-agent --classic
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Configure AWS CLI
aws configure set region ${aws_region}

# Wait for instance profile to be available
sleep 30

# Login to ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_uri}

# Create systemd service for the container
cat > /etc/systemd/system/bird-watchers-backend.service << 'EOF'
[Unit]
Description=Bird Watchers Emporium Backend Container
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run -d \
    --name bird-watchers-backend \
    --restart unless-stopped \
    -p ${backend_port}:8000 \
    -e ENVIRONMENT=${environment} \
    ${ecr_repository_uri}:latest
ExecStop=/usr/bin/docker stop bird-watchers-backend
ExecStopPost=/usr/bin/docker rm bird-watchers-backend

[Install]
WantedBy=multi-user.target
EOF

# Try to pull the image, but don't fail if it doesn't exist
echo "Attempting to pull image from ECR..."
if docker pull ${ecr_repository_uri}:latest 2>/dev/null; then
    echo "✅ Image found, starting container..."
    systemctl enable bird-watchers-backend.service
    systemctl start bird-watchers-backend.service
else
    echo "⚠️  Image not found in ECR. Container will start when image is pushed."
    systemctl enable bird-watchers-backend.service
    # Don't start the service yet - it will fail
fi

# Create a script to check for and start the container
cat > /usr/local/bin/start-backend.sh << 'EOF'
#!/bin/bash
ECR_URI=${ecr_repository_uri}
if docker pull $ECR_URI:latest 2>/dev/null; then
    echo "Starting backend container..."
    systemctl start bird-watchers-backend.service
    exit 0
else
    echo "Image not available yet"
    exit 1
fi
EOF

chmod +x /usr/local/bin/start-backend.sh

# Wait a bit for the container to start (if it did)
sleep 10

# Check if container is running
if docker ps | grep -q bird-watchers-backend; then
    echo "✅ Backend container started successfully"
else
    echo "ℹ️  Backend container not started (image not available yet)"
fi