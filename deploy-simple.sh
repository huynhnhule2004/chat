#!/bin/bash

# Simple Backend Deployment Script
SERVER="146.190.194.170"
USER="root"
PASSWORD="phNlSQmZWAqm"
REMOTE_PATH="/root/trung_dev"

echo "🚀 Deploying Chat Backend to Remote Server..."

# Create deployment package
echo "📦 Creating deployment package..."
cd backend

# Create a tar archive excluding unnecessary files
tar -czf ../backend-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='uploads' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='.env' \
    .

cd ..

# Create production environment file
echo "⚙️ Creating production environment..."
cat > backend-prod.env << EOF
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2ee?authSource=chate2ee
JWT_SECRET=prod-super-secret-jwt-key-$(openssl rand -base64 32)
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=104857600
MAX_AVATAR_SIZE=2097152
CORS_ORIGIN=*
API_RATE_LIMIT=100
AUTH_RATE_LIMIT=10
LOG_LEVEL=info
EOF

echo "📤 Uploading files to server..."

# Upload using scp (you'll be prompted for password)
scp backend-deploy.tar.gz backend-prod.env $USER@$SERVER:$REMOTE_PATH/

echo "🔧 Deploying on remote server..."

# Deploy on server (you'll be prompted for password)
ssh $USER@$SERVER << 'EOF'
cd /root/trung_dev

echo "🛑 Stopping existing services..."
if [ -f docker-compose.yml ]; then
    docker-compose down
fi

echo "📦 Extracting deployment package..."
tar -xzf backend-deploy.tar.gz
mv backend-prod.env .env

echo "🔨 Setting up directories..."
mkdir -p uploads/avatars
chmod -R 755 uploads

echo "🐳 Starting Docker services..."
docker-compose up --build -d

echo "⏳ Waiting for services to start..."
sleep 20

echo "🔍 Checking backend health..."
for i in {1..30}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Backend is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend failed to start"
        docker-compose logs backend
        exit 1
    fi
    echo "⏳ Waiting... ($i/30)"
    sleep 2
done

echo "🌱 Seeding database..."
docker-compose exec -T backend npm run seed

echo ""
echo "🎉 Deployment successful!"
echo "🔧 API: http://146.190.194.170:5000"
echo "📚 Docs: http://146.190.194.170:5000/api/docs"
echo ""
echo "Management commands:"
echo "  docker-compose logs -f"
echo "  docker-compose restart"
echo "  docker-compose down"
EOF

# Cleanup local files
rm -f backend-deploy.tar.gz backend-prod.env

echo ""
echo "✅ Deployment completed!"
echo "🌐 Backend URL: http://146.190.194.170:5000"
echo "📚 API Docs: http://146.190.194.170:5000/api/docs"
