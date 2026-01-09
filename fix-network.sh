#!/bin/bash

echo "🔧 Fixing port access issue"
echo "============================"

# Package new files
echo "📦 Creating updated package..."
cd backend
tar -czf ../backend-fix-network.tar.gz \
    --exclude='node_modules' \
    --exclude='uploads' \
    --exclude='.git' \
    --exclude='*.log' \
    .

cd ..
ls -lh backend-fix-network.tar.gz

echo ""
echo "📤 Uploading fix..."
scp backend-fix-network.tar.gz root@146.190.194.170:/root/trung_dev/

echo ""
echo "🛠️ Applying network fix..."

# SSH commands to fix the issue
ssh root@146.190.194.170 << 'EOF'
cd /root/trung_dev

echo "Stopping current service..."
docker compose down

echo "Extracting network fix..."
tar -xzf backend-fix-network.tar.gz

echo "Using fixed docker-compose..."
cp docker-compose-fixed.yml docker-compose.yml

echo "Opening firewall port..."
ufw allow 5000/tcp || echo "Firewall already configured"

echo "Starting with new network config..."
docker compose up -d --build

echo "Waiting for service..."
sleep 20

echo "Testing internal access..."
curl -s http://localhost:5000/health || echo "Internal test failed"

echo "Container status:"
docker compose ps

echo "Network info:"
docker network ls | grep backend
docker compose exec backend ip route | head -3 || echo "Route check failed"

echo ""
echo "✅ Network fix applied!"
echo "🌍 Try accessing: http://146.190.194.170:5000/health"
echo "📖 Swagger docs: http://146.190.194.170:5000/api/docs"

EOF

echo ""
echo "🧪 Testing external access..."
sleep 5
curl -s --connect-timeout 5 http://146.190.194.170:5000/health && echo "✅ External access works!" || echo "❌ Still blocked - may need server admin to open port"
