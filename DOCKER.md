# Chat Application - Docker Deployment

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- Git
- Make (optional, for convenience commands)

### Development Setup

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd chat
```

2. **Start development environment**
```bash
# Using Make (recommended)
make dev

# Or using Docker Compose directly
docker-compose -f docker-compose.dev.yml up --build
```

3. **Run database seeder**
```bash
# Wait for services to be healthy, then seed data
make seed-dev

# Or directly
docker-compose -f docker-compose.dev.yml exec backend npm run seed
```

4. **Access the application**
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:5000
- **API Documentation**: http://localhost:5000/api/docs
- **MongoDB**: localhost:27017 (admin/password123)

### Production Setup

1. **Start production environment**
```bash
make prod-detached
```

2. **Seed database**
```bash
make seed
```

3. **Access the application**
- **Application**: http://localhost (Nginx proxy)
- **Direct Backend**: http://localhost:5000
- **Direct Frontend**: http://localhost:3000

## 🐳 Docker Architecture

### Services Overview

| Service | Description | Port | Dependencies |
|---------|-------------|------|--------------|
| **mongodb** | MongoDB 7.x database | 27017 | - |
| **backend** | Node.js API server | 5000 | mongodb |
| **frontend** | Flutter web app | 3000 | backend |
| **seeder** | Database initialization | - | mongodb, backend |
| **redis** | Session storage | 6379 | - |
| **nginx** | Reverse proxy | 80, 443 | backend, frontend |

### Network Architecture
```
Internet → Nginx (80/443) → Backend (5000) → MongoDB (27017)
                         → Frontend (3000)
                         → Redis (6379)
```

## 📁 File Structure

```
chat/
├── docker-compose.yml          # Production configuration
├── docker-compose.dev.yml      # Development configuration
├── Makefile                    # Convenience commands
├── init-mongo.js              # MongoDB initialization
├── nginx/                     # Nginx configuration
│   ├── nginx.conf
│   └── conf.d/
│       └── default.conf
├── backend/
│   ├── Dockerfile             # Production backend image
│   ├── Dockerfile.dev         # Development backend image
│   ├── .dockerignore
│   └── ... (backend source)
└── flutter/
    ├── Dockerfile             # Frontend image
    ├── .dockerignore
    ├── nginx.conf
    └── ... (flutter source)
```

## 🛠 Make Commands

### Development
```bash
make dev              # Start development environment
make dev-detached     # Start development in background
make dev-down         # Stop development environment
make dev-logs         # Show development logs
make dev-clean        # Clean development environment
```

### Production
```bash
make prod             # Start production environment
make prod-detached    # Start production in background
make prod-down        # Stop production environment
make prod-logs        # Show production logs
make prod-clean       # Clean production environment
```

### Database
```bash
make seed             # Run database seeder (production)
make seed-dev         # Run database seeder (development)
make mongo-shell      # Open MongoDB shell (production)
make mongo-shell-dev  # Open MongoDB shell (development)
```

### Utilities
```bash
make build            # Build all images
make rebuild          # Force rebuild all images
make logs             # Show all logs
make logs-backend     # Show backend logs only
make ps               # Show running containers
make health           # Check service health
make clean            # Clean up containers and volumes
make clean-all        # Clean everything including images
```

## 🔧 Environment Variables

### Backend Environment

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `NODE_ENV` | Environment mode | `production` | Yes |
| `PORT` | Server port | `5000` | Yes |
| `MONGODB_URI` | MongoDB connection string | - | Yes |
| `JWT_SECRET` | JWT signing secret | - | Yes |
| `UPLOAD_DIR` | Upload directory | `./uploads` | No |

### MongoDB Environment

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGO_INITDB_ROOT_USERNAME` | MongoDB root user | `admin` |
| `MONGO_INITDB_ROOT_PASSWORD` | MongoDB root password | `password123` |
| `MONGO_INITDB_DATABASE` | Initial database | `chatapp` |

## 📊 Monitoring & Health Checks

### Health Check Endpoints
- **Backend**: `http://localhost:5000/health`
- **Frontend**: `http://localhost:3000`
- **Nginx**: `http://localhost:80/health`

### Check Service Status
```bash
# All services
make health

# Individual containers
docker-compose ps

# Service logs
make logs-backend
make logs-frontend
```

## 🔒 Security Features

### Production Security
- **Nginx**: Reverse proxy with rate limiting
- **Headers**: Security headers (XSS, CSRF, etc.)
- **File Upload**: Size limits and type validation
- **JWT**: Token-based authentication
- **E2EE**: End-to-end encryption for messages

### Network Security
- **Internal Network**: Services communicate on isolated Docker network
- **Port Exposure**: Only necessary ports exposed to host
- **Environment Variables**: Secrets managed via Docker environment

## 🚀 Deployment Options

### 1. Local Development
```bash
make dev
```

### 2. Local Production Test
```bash
make prod
```

### 3. Cloud Deployment

#### Docker Swarm
```bash
docker stack deploy -c docker-compose.yml chat-stack
```

#### Kubernetes
```bash
# Convert to Kubernetes manifests
kompose convert -f docker-compose.yml
kubectl apply -f .
```

#### Cloud Providers
- **AWS**: ECS with Fargate
- **GCP**: Cloud Run or GKE
- **Azure**: Container Instances or AKS

## 🐛 Troubleshooting

### Common Issues

1. **Port Already in Use**
```bash
# Check what's using the port
netstat -tulpn | grep :5000
# Kill the process or change port in docker-compose
```

2. **MongoDB Connection Issues**
```bash
# Check MongoDB logs
make logs-mongodb
# Verify connection string and credentials
```

3. **Permission Issues (Windows/WSL)**
```bash
# Fix upload directory permissions
make fix-permissions
```

4. **Build Failures**
```bash
# Clean Docker cache and rebuild
make clean-all
make rebuild
```

### Debug Mode

Start backend with debugging enabled:
```bash
# Development mode includes debug port 9229
make dev

# Connect debugger to localhost:9229
```

### Log Analysis
```bash
# Follow all logs
make logs

# Backend only
make logs-backend

# Save logs to file
docker-compose logs --no-color > app-logs.txt
```

## 📝 Database Seeding

The seeder creates:
- **Demo users** with RSA key pairs
- **Sample rooms** for testing
- **Database indexes** for performance
- **Initial admin user**

Run seeder:
```bash
# Development
make seed-dev

# Production  
make seed
```

## 🔄 Updates & Maintenance

### Update Application
```bash
# Pull latest changes
git pull

# Rebuild and restart
make rebuild
make prod-detached
```

### Backup Database
```bash
# Create backup
docker-compose exec mongodb mongodump --uri="mongodb://admin:password123@localhost:27017/chatapp" --authenticationDatabase=admin --out=/tmp/backup

# Copy backup from container
docker cp chat_mongodb:/tmp/backup ./mongodb-backup
```

### Restore Database
```bash
# Copy backup to container
docker cp ./mongodb-backup chat_mongodb:/tmp/restore

# Restore database
docker-compose exec mongodb mongorestore --uri="mongodb://admin:password123@localhost:27017/chatapp" --authenticationDatabase=admin /tmp/restore/chatapp
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Docker and application logs
3. Create an issue on the repository
4. Contact the development team

---

**Happy Chatting! 💬**
