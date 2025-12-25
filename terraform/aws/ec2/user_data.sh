#!/bin/bash

# User Data Script for Amazon Linux 2023
# This script installs Docker, Nginx and configures them to start at boot

# Update system
yum update -y

# Install Docker
yum install -y docker

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Configure Docker for ECR access
# Get AWS region from instance metadata
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Create ECR login helper script
cat > /home/ec2-user/ecr-login.sh << 'EOF'
#!/bin/bash
# ECR Login Helper Script
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
AWS_ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r '.AccountId' 2>/dev/null || echo "")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
fi

if [ ! -z "$AWS_ACCOUNT_ID" ] && [ ! -z "$AWS_REGION" ]; then
    echo "Logging into ECR for account $AWS_ACCOUNT_ID in region $AWS_REGION"
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    echo "ECR login completed"
else
    echo "Could not determine AWS Account ID or Region"
fi
EOF

chmod +x /home/ec2-user/ecr-login.sh
chown ec2-user:ec2-user /home/ec2-user/ecr-login.sh

# Install Nginx
yum install -y nginx

# Start and enable Nginx service
systemctl start nginx
systemctl enable nginx

# Install Git
yum install -y git

# Install Java (required for Jenkins)
yum install -y java-17-amazon-corretto-headless

# Add Jenkins repository and install Jenkins
yum install -y wget
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
yum install -y jenkins

# Start and enable Jenkins service
systemctl start jenkins
systemctl enable jenkins

# Configure Jenkins to start on boot
systemctl daemon-reload

# Create a simple index.html
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AWS Infrastructure Setup</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { background: #f0f8ff; padding: 20px; border-radius: 5px; }
        .service { margin: 10px 0; padding: 10px; background: #e8f5e8; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 AWS Infrastructure Setup Complete</h1>
        <div class="status">
            <h2>Server Status</h2>
            <div class="service">✅ Nginx - Running</div>
            <div class="service">✅ Docker - Running</div>
            <div class="service">✅ Jenkins - Running</div>
            <div class="service">✅ Git - Installed</div>
            <div class="service">✅ SSM Agent - Running</div>
        </div>
        <h2>Instance Information</h2>
        <p><strong>OS:</strong> Amazon Linux 2023</p>
        <p><strong>Services:</strong> Docker, Nginx, Jenkins, Git, ECR Access</p>
        <p><strong>Access:</strong> SSM Session Manager</p>
        <p><strong>Network:</strong> Private subnet behind NAT Gateway</p>
        
        <h2>Quick Commands</h2>
        <pre>
# Check Docker status
sudo systemctl status docker

# Check Nginx status  
sudo systemctl status nginx

# Check Jenkins status
sudo systemctl status jenkins

# View Docker containers
sudo docker ps

# Check Git version
git --version

# Get Jenkins initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Login to ECR (Amazon Container Registry)
/home/ec2-user/ecr-login.sh

# Pull Docker image from ECR
docker pull [account-id].dkr.ecr.[region].amazonaws.com/[repository]:[tag]

# Access via SSM (from AWS CLI)
aws ssm start-session --target INSTANCE_ID
        </pre>
    </div>
</body>
</html>
EOF

# Configure Nginx to serve on port 80
systemctl restart nginx

# Install SSM Agent (should be pre-installed on AL2023, but ensure it's running)
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Create a comprehensive service health check
cat > /home/ec2-user/service-health.sh << 'EOF'
#!/bin/bash
echo "=== Service Status Check ==="
echo "Docker Status: $(systemctl is-active docker)"
echo "Nginx Status: $(systemctl is-active nginx)"
echo "Jenkins Status: $(systemctl is-active jenkins)"
echo "SSM Agent Status: $(systemctl is-active amazon-ssm-agent)"
echo ""
echo "=== Git Version ==="
git --version
echo ""
echo "=== Docker Containers ==="
docker ps --format 'table {{.Names}}\t{{.Status}}'
echo ""
echo "=== Jenkins Initial Password ==="
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Jenkins Password: $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
else
    echo "Jenkins password file not found (Jenkins may still be starting)"
fi
EOF

chmod +x /home/ec2-user/service-health.sh

# Log completion
echo "$(date): User data script completed successfully" >> /var/log/user-data.log

# Signal completion
/opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource AutoScalingGroup --region ${AWS::Region} 2>/dev/null || echo "CFN signal not available"
