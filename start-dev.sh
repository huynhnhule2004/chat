#!/bin/bash

# Chat Application Development Startup Script
echo "🚀 Starting Chat Application Development Environment..."

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
if [ ! -f "./backend/.env" ]; then
    echo "📝 Creating .env file from template..."
    cp ./backend/.env.example ./backend/.env
    echo "⚠️  Please update ./backend/.env with your configuration"
fi

# Start development environment
echo "🐳 Starting Docker containers..."
docker-compose -f docker-compose.dev.yml up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

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
echo "🎉 Chat Application is ready!"
echo ""
echo "📱 Frontend: http://localhost:3000"
echo "🔧 Backend API: http://localhost:5000"
echo "📚 API Docs: http://localhost:5000/api/docs"
echo "🗄️  MongoDB: mongodb://admin:password123@localhost:27017/chatapp_dev"
echo ""
echo "📋 Useful commands:"
echo "  View logs: docker-compose -f docker-compose.dev.yml logs -f"
echo "  Stop: docker-compose -f docker-compose.dev.yml down"
echo "  Restart: docker-compose -f docker-compose.dev.yml restart"
echo ""
echo "🐛 Debug backend: Connect your IDE to localhost:9229"
echo ""
