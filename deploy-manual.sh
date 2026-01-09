#!/bin/bash

# Windows-compatible deployment script
echo "🚀 Starting manual deployment for Windows..."
echo "📋 Server: 146.190.194.170"
echo "👤 User: root"
echo "🔑 Password: phNlSQmZWAqm"
echo ""

# Create deployment package
echo "📦 Creating deployment package..."
cd backend

# Create .tar.gz without node_modules
tar -czf ../backend-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='uploads' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='.env' \
    --exclude='npm-debug.log*' \
    --exclude='yarn-debug.log*' \
    --exclude='yarn-error.log*' \
    --exclude='.DS_Store' \
    --exclude='Thumbs.db' \
    .

if [ $? -eq 0 ]; then
    echo "✅ Package created successfully: ../backend-deploy.tar.gz"
    ls -lh ../backend-deploy.tar.gz
else
    echo "❌ Failed to create package"
    exit 1
fi

cd ..

echo ""
echo "📤 Next steps (manual):"
echo "1. Upload backend-deploy.tar.gz to server using WinSCP, FileZilla, or:"
echo "   scp backend-deploy.tar.gz root@146.190.194.170:/root/trung_dev/"
echo ""
echo "2. Connect to server:"
echo "   ssh root@146.190.194.170"
echo "   Password: phNlSQmZWAqm"
echo ""
echo "3. Run these commands on the server:"
echo "   cd /root/trung_dev"
echo "   tar -xzf backend-deploy.tar.gz"
echo ""
echo "4. Create .env file:"
cat << 'EOF'
   cat > .env << 'ENVEOF'
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2ee?authSource=chate2ee
JWT_SECRET=prod-super-secret-jwt-key-change-me-123
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=104857600
MAX_AVATAR_SIZE=2097152
CORS_ORIGIN=*
API_RATE_LIMIT=100
AUTH_RATE_LIMIT=10
LOG_LEVEL=info
ENVEOF
EOF
echo ""
echo "5. Start services:"
echo "   mkdir -p uploads/avatars"
echo "   chmod -R 755 uploads"
echo "   docker-compose up --build -d"
echo "   sleep 20"
echo "   docker-compose exec -T backend npm run seed"
echo ""
echo "6. Test deployment:"
echo "   curl http://localhost:5000/health"
echo "   curl http://localhost:5000/api/docs"
echo ""
echo "🌐 Access URLs after deployment:"
echo "   API: http://146.190.194.170:5000"
echo "   Docs: http://146.190.194.170:5000/api/docs"
