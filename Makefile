# Chat Application Docker Management
.PHONY: help build up down logs clean dev prod seed test

# Default target
help: ## Show this help message
	@echo "Chat Application Docker Commands:"
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
seed: ## Run database seeder
	docker-compose exec backend npm run seed

seed-dev: ## Run database seeder in development
	docker-compose -f docker-compose.dev.yml exec backend npm run seed

# Utility commands
build: ## Build all images
	docker-compose build

rebuild: ## Force rebuild all images
	docker-compose build --no-cache

logs: ## Show all service logs
	docker-compose logs -f

logs-backend: ## Show backend logs only
	docker-compose logs -f backend

logs-frontend: ## Show frontend logs only
	docker-compose logs -f frontend

logs-mongodb: ## Show MongoDB logs only
	docker-compose logs -f mongodb

# Database management
mongo-shell: ## Open MongoDB shell
	docker-compose exec mongodb mongosh mongodb://admin:password123@localhost:27017/chatapp --authenticationDatabase admin

mongo-shell-dev: ## Open MongoDB shell (development)
	docker-compose -f docker-compose.dev.yml exec mongodb mongosh mongodb://admin:password123@localhost:27017/chatapp_dev --authenticationDatabase admin

# Container management
ps: ## Show running containers
	docker-compose ps

restart: ## Restart all services
	docker-compose restart

restart-backend: ## Restart backend service only
	docker-compose restart backend

restart-frontend: ## Restart frontend service only
	docker-compose restart frontend

# Cleanup commands
clean: ## Clean up containers, networks, and volumes
	docker-compose down -v
	docker system prune -f
	docker volume prune -f
	docker network prune -f

clean-all: ## Clean everything including images
	docker-compose down -v --rmi all
	docker system prune -af
	docker volume prune -f
	docker network prune -f

# Health check
health: ## Check service health
	@echo "Checking service health..."
	@curl -f http://localhost:5000/health && echo "Backend: ✅ Healthy" || echo "Backend: ❌ Unhealthy"
	@curl -f http://localhost:3000 && echo "Frontend: ✅ Healthy" || echo "Frontend: ❌ Unhealthy"
	@curl -f http://localhost:80/health && echo "Nginx: ✅ Healthy" || echo "Nginx: ❌ Unhealthy"

# Testing
test: ## Run API tests
	docker-compose exec backend npm run test:api

# File permissions fix (for Windows/WSL)
fix-permissions: ## Fix file permissions for uploads
	docker-compose exec backend chmod -R 755 /app/uploads
