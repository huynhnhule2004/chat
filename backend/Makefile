# Chat Backend Docker Management
.PHONY: help build up down logs clean dev prod seed test

# Default target
help: ## Show this help message
	@echo "Chat Backend Docker Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development commands
dev: ## Start development environment with hot reload
	docker-compose -f docker-compose.dev.yml up --build

dev-detached: ## Start development environment in background
	docker-compose -f docker-compose.dev.yml up --build -d

dev-down: ## Stop development environment
	docker-compose -f docker-compose.dev.yml down

dev-logs: ## Show development logs
	docker-compose -f docker-compose.dev.yml logs -f

dev-clean: ## Clean development environment (remove volumes)
	docker-compose -f docker-compose.dev.yml down -v
	docker system prune -f

# Production commands
prod: ## Start production environment
	docker-compose up --build

prod-detached: ## Start production environment in background
	docker-compose up --build -d

prod-down: ## Stop production environment
	docker-compose down

prod-logs: ## Show production logs
	docker-compose logs -f

prod-clean: ## Clean production environment (remove volumes)
	docker-compose down -v
	docker system prune -f

# Database commands
seed: ## Run database seeder (production)
	docker-compose exec backend npm run seed

seed-dev: ## Run database seeder (development)
	docker-compose -f docker-compose.dev.yml exec backend npm run seed

seed-force: ## Force run seeder (restart seeder container)
	docker-compose restart seeder

seed-force-dev: ## Force run seeder (restart seeder container in dev)
	docker-compose -f docker-compose.dev.yml restart seeder

# Utility commands
build: ## Build all images
	docker-compose build

build-dev: ## Build development images
	docker-compose -f docker-compose.dev.yml build

rebuild: ## Force rebuild all images
	docker-compose build --no-cache

rebuild-dev: ## Force rebuild development images
	docker-compose -f docker-compose.dev.yml build --no-cache

logs: ## Show all service logs
	docker-compose logs -f

logs-backend: ## Show backend logs only
	docker-compose logs -f backend

logs-mongodb: ## Show MongoDB logs only
	docker-compose logs -f mongodb

logs-redis: ## Show Redis logs only
	docker-compose logs -f redis

# Container management
ps: ## Show running containers
	docker-compose ps

restart: ## Restart all services
	docker-compose restart

restart-backend: ## Restart backend service only
	docker-compose restart backend

restart-mongodb: ## Restart MongoDB service only
	docker-compose restart mongodb

# Database management
mongo-shell: ## Open MongoDB shell (production)
	docker-compose exec mongodb mongosh mongodb://admin:password123@localhost:27017/chatapp --authenticationDatabase admin

mongo-shell-dev: ## Open MongoDB shell (development)
	docker-compose -f docker-compose.dev.yml exec mongodb mongosh mongodb://admin:password123@localhost:27017/chatapp_dev --authenticationDatabase admin

mongo-admin: ## Open Mongo Express web admin (development only)
	@echo "Opening Mongo Express at http://localhost:8081"
	@echo "Username: admin, Password: admin123"

# Redis management
redis-cli: ## Open Redis CLI
	docker-compose exec redis redis-cli

redis-cli-dev: ## Open Redis CLI (development)
	docker-compose -f docker-compose.dev.yml exec redis redis-cli

# Testing
test: ## Run API tests
	docker-compose exec backend npm run test:api

test-dev: ## Run API tests (development)
	docker-compose -f docker-compose.dev.yml exec backend npm run test:api

# Cleanup commands
clean: ## Clean up containers, networks, and volumes
	docker-compose down -v
	docker system prune -f
	docker volume prune -f
	docker network prune -f

clean-all: ## Clean everything including images
	docker-compose down -v --rmi all
	docker-compose -f docker-compose.dev.yml down -v --rmi all
	docker system prune -af
	docker volume prune -f
	docker network prune -f

# Health check
health: ## Check service health
	@echo "Checking Backend service health..."
	@curl -f http://localhost:5000/health && echo "Backend: ✅ Healthy" || echo "Backend: ❌ Unhealthy"

health-dev: ## Check development service health
	@echo "Checking Development services health..."
	@curl -f http://localhost:5000/health && echo "Backend: ✅ Healthy" || echo "Backend: ❌ Unhealthy"
	@curl -f http://localhost:8081 && echo "Mongo Express: ✅ Healthy" || echo "Mongo Express: ❌ Unhealthy"

# Development utilities
debug: ## Start backend with debugging enabled (development)
	docker-compose -f docker-compose.dev.yml exec backend npm run dev

install: ## Install new npm package (development)
	docker-compose -f docker-compose.dev.yml exec backend npm install $(PACKAGE)

shell: ## Open shell in backend container
	docker-compose exec backend sh

shell-dev: ## Open shell in development backend container
	docker-compose -f docker-compose.dev.yml exec backend sh

# File permissions fix (for Windows/WSL)
fix-permissions: ## Fix file permissions for uploads
	docker-compose exec backend chown -R nodejs:nodejs /app/uploads
	docker-compose exec backend chmod -R 755 /app/uploads

# Environment setup
setup: ## Initial setup - copy env file and start development
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "📝 Created .env file from template"; \
		echo "⚠️  Please update .env with your configuration"; \
	fi
	make dev-detached
	@echo "⏳ Waiting for services to start..."
	sleep 15
	make seed-dev
	@echo "🎉 Backend is ready!"
	@echo "🔧 Backend API: http://localhost:5000"
	@echo "📚 API Docs: http://localhost:5000/api/docs"
	@echo "🗄️  MongoDB: mongodb://admin:password123@localhost:27017/chatapp_dev"
	@echo "🌐 Mongo Express: http://localhost:8081 (admin/admin123)"

# Backup and restore
backup: ## Backup MongoDB data
	docker-compose exec mongodb mongodump --uri="mongodb://admin:password123@localhost:27017/chatapp" --authenticationDatabase=admin --out=/tmp/backup
	docker cp chat_backend_mongodb:/tmp/backup ./mongodb-backup-$(shell date +%Y%m%d_%H%M%S)

restore: ## Restore MongoDB data (specify BACKUP_DIR=path/to/backup)
	@if [ -z "$(BACKUP_DIR)" ]; then echo "❌ Please specify BACKUP_DIR=path/to/backup"; exit 1; fi
	docker cp $(BACKUP_DIR) chat_backend_mongodb:/tmp/restore
	docker-compose exec mongodb mongorestore --uri="mongodb://admin:password123@localhost:27017/chatapp" --authenticationDatabase=admin /tmp/restore/chatapp
