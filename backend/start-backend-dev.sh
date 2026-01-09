#!/bin/bash

# Chat Backend Development Startup Script
echo "🚀 Starting Chat Backend Development Environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose is not installed. Please install Docker Compose."
    exit 1
fi

echo "✅ Docker is ready"

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please update .env with your configuration"
fi

# Start development environment
echo "🐳 Starting Backend Docker containers..."
docker-compose -f docker-compose.dev.yml up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Check backend health
echo "🔍 Checking backend health..."
for i in {1..30}; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ Backend is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend failed to start. Check logs with: docker-compose -f docker-compose.dev.yml logs backend"
        exit 1
    fi
    echo "⏳ Waiting for backend... ($i/30)"
    sleep 2
done

# Seed database
echo "🌱 Seeding database..."
docker-compose -f docker-compose.dev.yml exec -T backend npm run seed

echo ""
echo "🎉 Chat Backend is ready!"
echo ""
echo "🔧 Backend API: http://localhost:5000"
echo "📚 API Docs: http://localhost:5000/api/docs"
echo "🗄️  MongoDB: mongodb://admin:password123@localhost:27017/chatapp_dev"
echo "🌐 Mongo Express: http://localhost:8081 (admin/admin123)"
echo "📊 Redis: localhost:6379"
echo ""
echo "📋 Useful commands:"
echo "  View logs: docker-compose -f docker-compose.dev.yml logs -f"
echo "  Stop: docker-compose -f docker-compose.dev.yml down"
echo "  Restart: docker-compose -f docker-compose.dev.yml restart"
echo "  MongoDB Shell: docker-compose -f docker-compose.dev.yml exec mongodb mongosh"
echo "  Redis CLI: docker-compose -f docker-compose.dev.yml exec redis redis-cli"
echo ""
echo "🐛 Debug backend: Connect your IDE to localhost:9229"
echo "🔧 Backend shell: docker-compose -f docker-compose.dev.yml exec backend sh"
echo ""
