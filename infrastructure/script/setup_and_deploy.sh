#!/bin/bash

set -e

echo "Starting to setup infrastructure and deployment..."

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

check_aws_configure() {
    aws_access_key=$(aws configure get aws_access_key_id 2>/dev/null)
    aws_secret_key=$(aws configure get aws_secret_access_key 2>/dev/null)
    if [ -n "$aws_access_key" ] && [ -n "$aws_secret_key" ]; then
        return 0
    else
        return 1
    fi
}

if [ -f "$INFRA_DIR/terraform.tfvars" ]; then
    echo "Using existing AWS credentials from terraform.tfvars"
else
    if check_aws_configure; then
        echo "Using AWS credentials from aws configure"
        aws_access_key=$(aws configure get aws_access_key_id)
        aws_secret_key=$(aws configure get aws_secret_access_key)
        
        {
            echo "aws_access_key = \"$aws_access_key\""
            echo "aws_secret_key = \"$aws_secret_key\""
        } > "$INFRA_DIR/terraform.tfvars"
    else
        echo "No AWS credentials found. Please provide AWS credentials"
        read -p "Enter AWS Access Key: " aws_access_key
        read -sp "Enter AWS Secret Key: " aws_secret_key
        echo

        {
            echo "aws_access_key = \"$aws_access_key\""
            echo "aws_secret_key = \"$aws_secret_key\""
        } > "$INFRA_DIR/terraform.tfvars"
    fi
fi

cd "$INFRA_DIR"
if [ ! -d ".terraform" ]; then
    echo "Initializing terraform..."
    terraform init
fi

echo "Running terraform plan..."
terraform plan -out=tfplan

read -p "Do you want to apply these changes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Deployment cancelled"
    exit 1
fi

echo "Applying terraform changes..."
terraform apply -auto-approve tfplan

if [ ! -f "terraform.tfvars" ]; then
    echo "Creating terraform.tfvars from current state..."
    {
        echo "aws_region           = \"$(terraform -chdir=.. output -raw aws_region)\""
        echo "aws_access_key       = \"$(terraform -chdir=.. output -raw aws_access_key)\""
        echo "aws_secret_key       = \"$(terraform -chdir=.. output -raw aws_secret_key)\""
        echo "ec2_instance_type    = \"$(terraform -chdir=.. output -raw ec2_instance_type)\""
        echo "ec2_key_name         = \"$(terraform -chdir=.. output -raw ec2_key_name)\""
        echo "ec2_ami_id           = \"$(terraform -chdir=.. output -raw ec2_ami_id)\""
        echo "rds_username         = \"$(terraform -chdir=.. output -raw rds_username)\""
        echo "rds_database_name    = \"$(terraform -chdir=.. output -raw rds_database_name)\""
        echo "rds_password         = \"$(terraform -chdir=.. output -raw rds_password)\""
        echo "rds_storage_size     = \"$(terraform -chdir=.. output -raw rds_storage_size)\""
        echo "redis_node_type      = \"$(terraform -chdir=.. output -raw redis_node_type)\""
        echo "redis_engine_version = \"$(terraform -chdir=.. output -raw redis_engine_version)\""
        echo "vpc_cidr_block      = \"$(terraform -chdir=.. output -raw vpc_cidr_block)\""
        echo "vpc_public_subnet_cidr  = \"$(terraform -chdir=.. output -raw vpc_public_subnet_cidr)\""
        echo "vpc_private_subnet_cidr = \"$(terraform -chdir=.. output -raw vpc_private_subnet_cidr)\""
        echo "vpc_availability_zone   = \"$(terraform -chdir=.. output -raw vpc_availability_zone)\""
        echo "environment         = \"$(terraform -chdir=.. output -raw environment)\""
    } > terraform.tfvars
else
    echo "terraform.tfvars already exists, skipping creation"
fi

echo "Setting up environment variables..."
export ECR_REPOSITORY_URL=$(terraform -chdir="$INFRA_DIR" output -raw ecr_repository_url)
export EC2_INSTANCE_IP=$(terraform -chdir="$INFRA_DIR" output -raw ec2_public_ip)
export APP_HOST=$(terraform -chdir="$INFRA_DIR" output -raw ec2_public_dns)
export ECR_PASSWORD=$(aws ecr get-login-password)

echo "Setting up system dependencies and Docker on the instance..."
ssh -o StrictHostKeyChecking=no -i "$INFRA_DIR/your-ec2-key.pem" ubuntu@$EC2_INSTANCE_IP << 'EOF'
    sudo apt update
    sudo apt upgrade -y
    sudo apt remove -y containerd
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker ubuntu
    sudo systemctl start docker
    sudo systemctl enable docker
EOF

echo "Checking for Kamal installation..."
if ! command -v kamal &> /dev/null; then
    echo "Installing Kamal..."
    gem install kamal
    # Add gem bin directory to PATH
    export PATH="$PATH:$(gem environment gemdir)/bin"
fi

# Ensure gem bin directory is in PATH
export PATH="$PATH:$(gem environment gemdir)/bin"

echo "Setting up kamal..."
cd ..
kamal setup

# print ec2 ip and public dns
echo "EC2 IP: $EC2_INSTANCE_IP"
echo "Public DNS: $APP_HOST"
echo "Monitoring URL: http://$APP_HOST:19999"
echo "Deployment completed successfully!" 