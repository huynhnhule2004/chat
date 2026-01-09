#!/bin/bash

# Test connection to remote server
SERVER="146.190.194.170"
USER="root"
PASSWORD="phNlSQmZWAqm"

echo "🔗 Testing connection to remote server..."

# Test SSH connection
echo "📡 Testing SSH connection..."
if sshpass -p "$PASSWORD" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $USER@$SERVER 'echo "SSH connection successful"'; then
    echo "✅ SSH connection: OK"
else
    echo "❌ SSH connection: FAILED"
    exit 1
fi

echo ""
echo "🐳 Checking Docker installation on server..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no $USER@$SERVER << 'EOF'
echo "Docker version:"
docker --version

echo ""
echo "Docker Compose version:"
docker-compose --version

echo ""
echo "Docker status:"
systemctl status docker --no-pager -l

echo ""
echo "Available disk space:"
df -h

echo ""
echo "Available memory:"
free -h

echo ""
echo "Current directory contents of /root:"
ls -la /root/

echo ""
echo "Creating trung_dev directory if not exists:"
mkdir -p /root/trung_dev
echo "Directory /root/trung_dev ready"

echo ""
echo "✅ Server is ready for deployment!"
EOF
