# 🚀 Remote Server Deployment Guide

## 📋 Prerequisites

- Server IP: `146.190.194.170`
- SSH User: `root`
- SSH Password: `phNlSQmZWAqm`
- Docker & Docker Compose already installed on server

## 🔧 Deployment Options

### Option 1: Automated Deployment (Linux/Mac)

```bash
# Make scripts executable
chmod +x deploy-simple.sh check-server.sh

# Check server connectivity first
./check-server.sh

# Deploy backend
./deploy-simple.sh
```

### Option 2: Manual Deployment

#### Step 1: Connect to Server
```bash
ssh root@146.190.194.170
# Password: phNlSQmZWAqm
```

#### Step 2: Create Deployment Directory
```bash
mkdir -p /root/trung_dev
cd /root/trung_dev
```

#### Step 3: Upload Backend Files

**From your local machine:**
```bash
# Create deployment package
cd backend
tar -czf ../backend-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='uploads' \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='.env' \
    .

# Upload to server
scp ../backend-deploy.tar.gz root@146.190.194.170:/root/trung_dev/
```

#### Step 4: Extract and Configure on Server

**Back on the server:**
```bash
cd /root/trung_dev

# Extract files
tar -xzf backend-deploy.tar.gz

# Create production .env file
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2e?authSource=chate2ee
JWT_SECRET=prod-super-secret-jwt-key-change-me-$(date +%s)
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=104857600
MAX_AVATAR_SIZE=2097152
CORS_ORIGIN=*
API_RATE_LIMIT=100
AUTH_RATE_LIMIT=10
LOG_LEVEL=info
EOF

# Create uploads directory
mkdir -p uploads/avatars
chmod -R 755 uploads
```

#### Step 5: Start Services

```bash
# Start Docker services
docker-compose up --build -d

# Wait for services to start
sleep 20

# Check health
curl http://localhost:5000/health

# Seed database
docker-compose exec -T backend npm run seed
```

### Option 3: Windows PowerShell Deployment

```powershell
# Connect using PowerShell SSH (Windows 10+)
ssh root@146.190.194.170

# Or use PuTTY if available
# Run deploy-backend.bat (requires PuTTY tools)
```

## 📊 Verify Deployment

### Check Services Status
```bash
# On the server
cd /root/trung_dev

# Check running containers
docker-compose ps

# Check logs
docker-compose logs -f backend

# Test API
curl http://localhost:5000/health
curl http://localhost:5000/api/docs
```

### External Access
- **API Endpoint**: http://146.190.194.170:5000
- **API Documentation**: http://146.190.194.170:5000/api/docs
- **Health Check**: http://146.190.194.170:5000/health

## 🛠 Management Commands

### On the Server (`/root/trung_dev`):

```bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update deployment
docker-compose down
# (upload new files)
docker-compose up --build -d

# Database operations
docker-compose exec backend npm run seed
docker-compose exec mongodb mongosh

# Backend shell access
docker-compose exec backend sh

# Check service health
curl http://localhost:5000/health
```

## 🔧 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check if port 5000 is open
   netstat -tulpn | grep :5000
   
   # Check firewall
   ufw status
   ufw allow 5000/tcp
   ```

2. **Docker Service Issues**
   ```bash
   # Check Docker status
   systemctl status docker
   
   # Restart Docker
   systemctl restart docker
   
   # View container logs
   docker-compose logs backend
   ```

3. **Database Connection Issues**
   ```bash
   # Check MongoDB status
   systemctl status mongod
   
   # Test connection
   mongosh "mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2ee?authSource=chate2ee"
   ```

4. **Permission Issues**
   ```bash
   # Fix upload permissions
   chmod -R 755 uploads
   chown -R 1001:1001 uploads
   ```

### Service Health Checks

```bash
# Backend API
curl -f http://localhost:5000/health

# MongoDB
docker-compose exec mongodb mongosh --eval "db.runCommand('ping')"

# Container status
docker-compose ps

# Resource usage
docker stats
```

## 🔄 Updates & Maintenance

### Deploy New Version

```bash
# On local machine
./deploy-simple.sh

# Or manually
cd /root/trung_dev
docker-compose down
# Upload new files
docker-compose up --build -d
```

### Backup Database

```bash
# Create backup
docker-compose exec mongodb mongodump \
    --uri="mongodb://chate2ee_user:ChatE2EEPass123!@localhost:27017/chate2ee?authSource=chate2ee" \
    --out=/tmp/backup

# Copy backup from container
docker cp $(docker-compose ps -q mongodb):/tmp/backup ./mongodb-backup-$(date +%Y%m%d)
```

### Monitor Logs

```bash
# Follow all logs
docker-compose logs -f

# Backend only
docker-compose logs -f backend

# Save logs to file
docker-compose logs --no-color > deployment-logs.txt
```

## 📞 Support

### Quick Commands

```bash
# SSH to server
ssh root@146.190.194.170

# Go to deployment directory
cd /root/trung_dev

# Check everything
docker-compose ps && curl -s http://localhost:5000/health
```

### Log Collection

```bash
# Collect deployment info
echo "=== Docker Compose PS ===" > debug-info.txt
docker-compose ps >> debug-info.txt
echo -e "\n=== Backend Logs ===" >> debug-info.txt
docker-compose logs --tail=50 backend >> debug-info.txt
echo -e "\n=== System Info ===" >> debug-info.txt
df -h >> debug-info.txt
free -h >> debug-info.txt
```

---
**Deployment Ready! 🎉**
