@echo off
REM Chat Backend Development Startup Script for Windows

echo 🚀 Starting Chat Backend Development Environment...

REM Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker is not running. Please start Docker Desktop first.
    pause
    exit /b 1
)

echo ✅ Docker is ready

REM Create .env file if it doesn't exist
if not exist ".env" (
    echo 📝 Creating .env file from template...
    copy ".env.example" ".env"
    echo ⚠️  Please update .env with your configuration
)

REM Start development environment
echo 🐳 Starting Backend Docker containers...
docker-compose -f docker-compose.dev.yml up --build -d

REM Wait for services to be ready
echo ⏳ Waiting for services to start...
timeout /t 15 /nobreak >nul

REM Check backend health
echo 🔍 Checking backend health...
set /a counter=0
:healthcheck
set /a counter+=1
curl -f http://localhost:5000/health >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Backend is ready!
    goto :seed
)
if %counter% geq 30 (
    echo ❌ Backend failed to start. Check logs with: docker-compose -f docker-compose.dev.yml logs backend
    pause
    exit /b 1
)
echo ⏳ Waiting for backend... (%counter%/30)
timeout /t 2 /nobreak >nul
goto :healthcheck

:seed
REM Seed database
echo 🌱 Seeding database...
docker-compose -f docker-compose.dev.yml exec -T backend npm run seed

echo.
echo 🎉 Chat Backend is ready!
echo.
echo 🔧 Backend API: http://localhost:5000
echo 📚 API Docs: http://localhost:5000/api/docs
echo 🗄️  MongoDB: mongodb://admin:password123@localhost:27017/chatapp_dev
echo 🌐 Mongo Express: http://localhost:8081 (admin/admin123)
echo 📊 Redis: localhost:6379
echo.
echo 📋 Useful commands:
echo   View logs: docker-compose -f docker-compose.dev.yml logs -f
echo   Stop: docker-compose -f docker-compose.dev.yml down
echo   Restart: docker-compose -f docker-compose.dev.yml restart
echo   MongoDB Shell: docker-compose -f docker-compose.dev.yml exec mongodb mongosh
echo   Redis CLI: docker-compose -f docker-compose.dev.yml exec redis redis-cli
echo.
echo 🐛 Debug backend: Connect your IDE to localhost:9229
echo 🔧 Backend shell: docker-compose -f docker-compose.dev.yml exec backend sh
echo.
echo Press any key to exit...
pause >nul
