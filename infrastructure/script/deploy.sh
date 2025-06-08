#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$INFRA_DIR")"

echo "Starting application deployment..."

if [ ! -f "$INFRA_DIR/terraform.tfstate" ]; then
    echo "Error: Terraform state file not found"
    echo "Please run setup_and_deploy.sh first"
    exit 1
fi

# Change to infrastructure directory
cd "$INFRA_DIR"

echo "Setting up environment variables..."

# Export environment variables directly
export ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
export EC2_INSTANCE_IP=$(terraform output -raw ec2_public_ip)
export APP_HOST=$(terraform output -raw ec2_public_dns)
export ECR_PASSWORD=$(aws ecr get-login-password)

echo "Environment variables set successfully!"

echo "Deploying application..."
cd "$ROOT_DIR"
kamal deploy

echo "Application deployment completed successfully!" 