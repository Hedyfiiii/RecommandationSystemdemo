#!/bin/bash
set -e

IMAGE_TAG=$1
ECR_REGISTRY=$2
REGION="us-east-1"

echo "🚀 Starting deployment..."
echo "Image: $ECR_REGISTRY/recommendation-system:$IMAGE_TAG"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Stop and remove old container
echo "🛑 Stopping old container..."
docker stop spring-app 2>/dev/null || true
docker rm spring-app 2>/dev/null || true

# Pull new image
echo "📥 Pulling new image..."
docker pull $ECR_REGISTRY/recommendation-system:$IMAGE_TAG

# Run new container
echo "▶️  Starting new container..."
docker run -d \
  --name spring-app \
  -p 80:8080 \
  --restart unless-stopped \
  -e SPRING_PROFILES_ACTIVE=prod \
  $ECR_REGISTRY/recommendation-system:$IMAGE_TAG

# Wait for startup
echo "⏳ Waiting for application to start..."
sleep 10

# Health check
echo "🏥 Performing health check..."
MAX_ATTEMPTS=12
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  if curl -f http://localhost/actuator/health 2>/dev/null; then
    echo "✅ Deployment successful! Application is healthy."
    exit 0
  fi
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting..."
  ATTEMPT=$((ATTEMPT + 1))
  sleep 5
done

echo "❌ Health check failed"
docker logs spring-app --tail 50
exit 1