#!/bin/bash
set -e

IMAGE_TAG=$1
ECR_REGISTRY=$2
REGION="us-west-1"
ACCOUNT_ID="998291852268"
REPOSITORY_NAME="recommendation-system"

echo "=========================================="
echo "🚀 Starting Deployment"
echo "=========================================="
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo "Repository: $REPOSITORY_NAME"
echo "Image Tag: $IMAGE_TAG"
echo "ECR Registry: $ECR_REGISTRY"
echo "=========================================="

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed"
    exit 1
fi
echo "✅ AWS CLI: $(aws --version)"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not installed"
    exit 1
fi
echo "✅ Docker: $(docker --version)"

# Check IAM credentials
echo "🔍 Checking IAM credentials..."
if ! aws sts get-caller-identity --region $REGION &> /dev/null; then
    echo "❌ No IAM role attached to EC2 instance"
    echo "Please attach an IAM role with ECR permissions"
    exit 1
fi
echo "✅ IAM Role: $(aws sts get-caller-identity --query 'Arn' --output text)"

# Check ECR repository exists
echo "🔍 Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION &> /dev/null; then
    echo "❌ ECR repository '$REPOSITORY_NAME' not found in $REGION"
    echo "Creating repository..."
    aws ecr create-repository --repository-name $REPOSITORY_NAME --region $REGION
fi
echo "✅ ECR repository exists"

# Login to ECR
echo "🔐 Logging into ECR..."
if ! aws ecr get-login-password --region $REGION | \
     docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com; then
    echo "❌ ECR login failed"
    echo "Debug info:"
    echo "  - Region: $REGION"
    echo "  - Account: $ACCOUNT_ID"
    echo "  - ECR URL: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
    exit 1
fi
echo "✅ ECR login successful"

# Stop and remove old container
echo "🛑 Stopping old container..."
docker stop $REPOSITORY_NAME 2>/dev/null || echo "No container to stop"
docker rm $REPOSITORY_NAME 2>/dev/null || echo "No container to remove"

# Pull new image
echo "📥 Pulling image: $ECR_REGISTRY/$REPOSITORY_NAME:$IMAGE_TAG"
if ! docker pull $ECR_REGISTRY/$REPOSITORY_NAME:$IMAGE_TAG; then
    echo "❌ Failed to pull image"
    echo "Available images in ECR:"
    aws ecr list-images --repository-name $REPOSITORY_NAME --region $REGION
    exit 1
fi
echo "✅ Image pulled successfully"

# Run new container
echo "▶️  Starting container..."
docker run -d \
  --name $REPOSITORY_NAME \
  -p 80:8080 \
  --restart unless-stopped \
  $ECR_REGISTRY/$REPOSITORY_NAME:$IMAGE_TAG

echo "✅ Container started"

# Wait for startup
echo "⏳ Waiting for application to start..."
sleep 15

# Health check
echo "🏥 Performing health check..."
MAX_ATTEMPTS=12
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  if curl -f http://localhost/actuator/health 2>/dev/null; then
    echo "=========================================="
    echo "✅ DEPLOYMENT SUCCESSFUL! 🎉"
    echo "=========================================="
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    echo "🌐 Access your app at: http://${PUBLIC_IP}"
    echo "=========================================="
    exit 0
  fi
  echo "⏳ Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting..."
  ATTEMPT=$((ATTEMPT + 1))
  sleep 5
done

echo "=========================================="
echo "❌ HEALTH CHECK FAILED"
echo "=========================================="
echo "Container logs:"
docker logs $REPOSITORY_NAME --tail 50
echo "=========================================="
exit 1