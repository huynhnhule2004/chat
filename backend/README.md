# Chat Backend - Docker Setup

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- Git

### Option 1: Using Scripts (Recommended)

#### Windows
```cmd
start-backend-dev.bat
```

#### Linux/Mac
```bash
chmod +x start-backend-dev.sh
./start-backend-dev.sh
```

### Option 2: Using Make Commands

```bash
# First-time setup
make setup

# Or manual steps
make dev-detached
make seed-dev
```

### Option 3: Manual Docker Compose

```bash
# Development
docker-compose -f docker-compose.dev.yml up --build -d

# Production
docker-compose up --build -d

# Seed database
docker-compose -f docker-compose.dev.yml exec backend npm run seed
```

## 📋 Services

| Service | Description | Port | URL |
|---------|-------------|------|-----|
| **Backend API** | Node.js Express server | 5000 | http://localhost:5000 |
| **MongoDB** | Database | 27017 | mongodb://admin:password123@localhost:27017 |
| **Redis** | Cache & Session store | 6379 | redis://localhost:6379 |
| **Mongo Express** | Database admin UI | 8081 | http://localhost:8081 |

## 🛠 Make Commands

### Development
```bash
make dev              # Start development with hot reload
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
```

### Database
```bash
make seed             # Run database seeder (production)
make seed-dev         # Run database seeder (development)
make mongo-shell      # Open MongoDB shell (production)
make mongo-shell-dev  # Open MongoDB shell (development)
make mongo-admin      # Open Mongo Express web admin
```

### Utilities
```bash
make build            # Build all images
make rebuild          # Force rebuild all images
make logs-backend     # Show backend logs only
make logs-mongodb     # Show MongoDB logs only
make health           # Check service health
make clean            # Clean up containers and volumes
```

## 🔧 Environment Configuration

### Development Environment (docker-compose.dev.yml)

- **Hot Reload**: Code changes trigger automatic restart
- **Debug Port**: 9229 for IDE debugging
- **Mongo Express**: Web-based MongoDB admin interface
- **Volume Mounting**: Live code editing
- **Development Database**: `chatapp_dev`

### Production Environment (docker-compose.yml)

- **Optimized Build**: Multi-stage Docker build
- **Security**: Non-root user, minimal attack surface
- **Health Checks**: Automatic service monitoring
- **Data Persistence**: Named volumes for data
- **Production Database**: `chatapp`

## 📊 API Endpoints

### Access Points
- **API Base**: http://localhost:5000/api
- **Health Check**: http://localhost:5000/health
- **Swagger Documentation**: http://localhost:5000/api/docs
- **Swagger JSON**: http://localhost:5000/api/docs/swagger.json

### Main Routes
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `GET /api/users/search` - Search users
- `GET /api/messages/{userId}` - Get messages
- `POST /api/messages` - Send message
- `POST /api/groups/create` - Create group
- `POST /api/files/upload` - Upload file

## 🗄️ Database Management

### MongoDB Access

#### Via Docker (Recommended)
```bash
# Development database
make mongo-shell-dev

# Production database  
make mongo-shell

# Web interface
make mongo-admin
# Then visit http://localhost:8081
# Username: admin, Password: admin123
```

#### Direct Connection
```bash
# Development
mongodb://admin:password123@localhost:27017/chatapp_dev

# Production
mongodb://admin:password123@localhost:27017/chatapp
```

### Database Seeding

The seed script creates:
- Demo users with RSA key pairs
- Sample chat rooms
- Database indexes for performance
- Admin user account

```bash
# Run seeder
make seed-dev

# Force re-run seeder
make seed-force-dev
```

### Data Backup & Restore

```bash
# Backup
make backup

# Restore (specify backup directory)
make restore BACKUP_DIR=./mongodb-backup-20240101_120000
```

## 🐛 Development & Debugging

### Hot Reload Development

```bash
# Start with hot reload
make dev

# View logs in real-time
make dev-logs

# Restart just the backend
make restart-backend
```

### Debug Mode

The development environment exposes port 9229 for debugging:

1. Start development environment: `make dev-detached`
2. Connect your IDE debugger to `localhost:9229`
3. Set breakpoints in your code
4. Debug API requests

### Container Shell Access

```bash
# Backend container shell
make shell-dev

# MongoDB container shell
docker-compose -f docker-compose.dev.yml exec mongodb bash
```

### Install New Packages

```bash
# Install new npm package
make install PACKAGE=express-rate-limit

# Or manually
docker-compose -f docker-compose.dev.yml exec backend npm install package-name
```

## 🔒 Security Features

### Production Security
- **Non-root User**: Backend runs as `nodejs` user
- **JWT Authentication**: Token-based API authentication
- **CORS Protection**: Cross-origin request filtering
- **Rate Limiting**: API endpoint protection
- **File Upload Limits**: Size and type restrictions
- **Input Validation**: Request payload validation

### Environment Variables

Copy `.env.example` to `.env` and update:

```env
NODE_ENV=development
PORT=5000
MONGODB_URI=mongodb://admin:password123@mongodb:27017/chatapp_dev?authSource=admin
JWT_SECRET=your-super-secret-jwt-key
```

## 🚀 Deployment

### Local Development
```bash
make dev
```

### Local Production Testing
```bash
make prod
```

### Cloud Deployment

The Docker images are ready for deployment to:
- **AWS ECS/Fargate**
- **Google Cloud Run**
- **Azure Container Instances**
- **Kubernetes clusters**
- **VPS with Docker**

### Environment-specific Configurations

Update `docker-compose.yml` for production:
- Use external MongoDB service
- Configure SSL certificates
- Set up reverse proxy (nginx)
- Configure logging and monitoring

## 🔄 Health Monitoring

### Health Checks

All services include health checks:
- **Backend**: HTTP endpoint `/health`
- **MongoDB**: Database ping
- **Redis**: Redis ping

```bash
# Check all service health
make health-dev

# Manual health check
curl http://localhost:5000/health
```

### Logging

```bash
# All services
make logs

# Backend only
make logs-backend

# MongoDB only  
make logs-mongodb

# Follow logs in real-time
make dev-logs
```

## 🧹 Cleanup

### Development Cleanup
```bash
# Stop and remove containers/volumes
make dev-clean

# Complete cleanup (including images)
make clean-all
```

### Disk Space Management
```bash
# Remove unused Docker resources
docker system prune -f

# Remove all stopped containers
docker container prune -f

# Remove unused volumes
docker volume prune -f
```

## 🚨 Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check what's using port 5000
netstat -tulpn | grep :5000
# or
lsof -i :5000

# Kill process or change port in docker-compose
```

#### Permission Issues (Windows/WSL)
```bash
# Fix upload directory permissions
make fix-permissions
```

#### MongoDB Connection Issues
```bash
# Check MongoDB logs
make logs-mongodb

# Verify MongoDB is running
docker-compose -f docker-compose.dev.yml ps mongodb
```

#### Container Build Failures
```bash
# Clean Docker cache and rebuild
make clean-all
make rebuild-dev
```

### Debug Steps

1. **Check service status**: `make ps`
2. **View logs**: `make logs-backend`
3. **Test health**: `make health-dev`
4. **Check environment**: Verify `.env` file
5. **Restart services**: `make restart`

### Log Analysis
```bash
# Save logs to file
docker-compose -f docker-compose.dev.yml logs --no-color > backend-logs.txt

# Filter logs by service
docker-compose -f docker-compose.dev.yml logs backend | grep ERROR
```

## 📞 Support

For issues:
1. Check troubleshooting section above
2. Review container logs: `make logs`
3. Verify Docker resources: `docker system df`
4. Create GitHub issue with logs and configuration

---

**Happy Backend Development! 🚀**
