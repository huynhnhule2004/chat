#!/bin/bash

# Deploy Chat Backend to Remote Server
SERVER="146.190.194.170"
USER="root"
PASSWORD="phNlSQmZWAqm"
REMOTE_PATH="/root/trung_dev"

echo "🚀 Deploying Chat Backend to Remote Server..."

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass is not installed. Installing..."
    # For Ubuntu/Debian
    sudo apt-get update && sudo apt-get install -y sshpass
    # For macOS (if Homebrew is available)
    # brew install hudochenkov/sshpass/sshpass
fi

echo "📦 Preparing backend files for deployment..."

# Create temporary deployment directory
TEMP_DIR="/tmp/backend_deploy"
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

# Copy backend files (excluding node_modules and uploads)
echo "📁 Copying backend files..."
rsync -av --exclude 'node_modules' --exclude 'uploads' --exclude '.git' --exclude '*.log' ./backend/ $TEMP_DIR/

# Create production environment file
echo "⚙️  Creating production .env file..."
cat > $TEMP_DIR/.env << EOF
# Production Environment for Remote Server
NODE_ENV=production
PORT=5000

# Remote MongoDB Connection
MONGODB_URI=mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2ee?authSource=chate2ee

# JWT Secret (Change this in production!)
JWT_SECRET=prod-super-secret-jwt-key-change-me-$(date +%s)

# File Upload Settings
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=104857600
MAX_AVATAR_SIZE=2097152

# CORS Configuration
CORS_ORIGIN=*

# API Rate Limiting
API_RATE_LIMIT=100
AUTH_RATE_LIMIT=10

# Logging
LOG_LEVEL=info
EOF

echo "🔗 Connecting to remote server and setting up..."

# Create remote directory and copy files
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$SERVER << 'REMOTE_SCRIPT'
    echo "📁 Creating deployment directory..."
    mkdir -p /root/trung_dev
    cd /root/trung_dev
    
    # Stop existing containers if running
    if [ -f docker-compose.yml ]; then
        echo "🛑 Stopping existing containers..."
        docker-compose down
    fi
    
    echo "✅ Server setup ready"
REMOTE_SCRIPT

# Copy files to remote server
echo "📤 Uploading backend files to server..."
sshpass -p "$PASSWORD" rsync -avz --progress -e "ssh -o StrictHostKeyChecking=no" $TEMP_DIR/ $USER@$SERVER:$REMOTE_PATH/

# Deploy and start services on remote server
echo "🐳 Starting Docker services on remote server..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$SERVER << REMOTE_DEPLOY
    cd /root/trung_dev
    
    echo "🔍 Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    echo "✅ Docker is available"
    
    # Create uploads directory
    mkdir -p uploads/avatars
    chmod -R 755 uploads
    
    echo "🐳 Starting Docker services..."
    docker-compose up --build -d
    
    echo "⏳ Waiting for services to start..."
    sleep 20
    
    echo "🔍 Checking service health..."
    for i in {1..30}; do
        if curl -f http://localhost:5000/health > /dev/null 2>&1; then
            echo "✅ Backend is ready!"
            break
        fi
        if [ \$i -eq 30 ]; then
            echo "❌ Backend failed to start. Checking logs..."
            docker-compose logs backend
            exit 1
        fi
        echo "⏳ Waiting for backend... (\$i/30)"
        sleep 2
    done
    
    echo "🌱 Seeding database..."
    docker-compose exec -T backend npm run seed
    
    echo ""
    echo "🎉 Backend deployed successfully!"
    echo ""
    echo "🔧 Backend API: http://$SERVER:5000"
    echo "📚 API Docs: http://$SERVER:5000/api/docs"
    echo "🗄️  MongoDB: Local MongoDB on server"
    echo ""
    echo "📋 Useful commands on server:"
    echo "  cd /root/trung_dev"
    echo "  docker-compose logs -f                 # View logs"
    echo "  docker-compose restart                 # Restart services"
    echo "  docker-compose down                    # Stop services"
    echo "  docker-compose exec backend sh         # Backend shell"
    echo ""
REMOTE_DEPLOY

# Cleanup local temp files
rm -rf $TEMP_DIR

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "🌐 Your backend is now running at: http://$SERVER:5000"
echo "📚 API Documentation: http://$SERVER:5000/api/docs"
echo ""
echo "🔧 To manage the deployment:"
echo "  ssh root@$SERVER"
echo "  cd /root/trung_dev"
echo "  docker-compose logs -f"
echo ""
