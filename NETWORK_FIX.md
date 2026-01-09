# 🔧 Fix External API Access

## Vấn đề hiện tại:
- Backend container đang chạy thành công
- API hoạt động bình thường từ bên trong server
- **Không thể truy cập từ bên ngoài** qua http://146.190.194.170:5000

## 🛠️ Giải pháp:

### Bước 1: Kết nối SSH và check firewall
```bash
ssh root@146.190.194.170
cd /root/trung_dev
```

### Bước 2: Kiểm tra và mở firewall
```bash
# Check firewall status
ufw status

# Enable port 5000
ufw allow 5000/tcp

# Check if port is listening
netstat -tulpn | grep :5000
```

### Bước 3: Fix Docker network configuration
```bash
# Stop current container
docker compose down

# Create new docker-compose.yml without host network
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: chat_backend_api
    restart: unless-stopped
    ports:
      - "5000:5000"
    environment:
      NODE_ENV: production
      PORT: 5000
      MONGODB_URI: mongodb://chate2ee_user:ChatE2EEPass123!@172.17.0.1:27017/chate2ee?authSource=chate2ee
      JWT_SECRET: prod-super-secret-jwt-key-change-me-123
      UPLOAD_DIR: /app/uploads
      MAX_FILE_SIZE: 104857600
      MAX_AVATAR_SIZE: 2097152
      CORS_ORIGIN: "*"
      API_RATE_LIMIT: 100
      AUTH_RATE_LIMIT: 10
      LOG_LEVEL: info
    volumes:
      - uploads_data:/app/uploads
    networks:
      - backend_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  uploads_data:
    driver: local

networks:
  backend_network:
    driver: bridge
EOF
```

### Bước 4: Restart với cấu hình mới
```bash
# Start with new config
docker compose up -d --build

# Wait and check
sleep 20
docker compose ps

# Test internal access
curl http://localhost:5000/health
curl -I http://localhost:5000/api/docs
```

### Bước 5: Check từ máy local
Sau khi áp dụng fix, test từ browser hoặc terminal:

```bash
# Health check
curl http://146.190.194.170:5000/health

# Swagger UI
curl -I http://146.190.194.170:5000/api/docs
```

## 🌍 URLs sau khi fix:
- **Health**: http://146.190.194.170:5000/health
- **Swagger**: http://146.190.194.170:5000/api/docs  
- **API Base**: http://146.190.194.170:5000/api

## 🔍 Debug commands:
```bash
# Check container logs
docker compose logs backend --tail=20

# Check network
docker network inspect trung_dev_backend_network

# Check port binding
docker port chat_backend_api

# Test from container
docker compose exec backend curl localhost:5000/health
```

Vấn đề chính là **firewall** và **Docker network configuration**. Sau khi áp dụng fix trên, API sẽ accessible từ bên ngoài! 🚀
