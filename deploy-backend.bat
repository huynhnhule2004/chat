@echo off
REM Deploy Chat Backend to Remote Server (Windows)

set SERVER=146.190.194.170
set USER=root
set PASSWORD=phNlSQmZWAqm
set REMOTE_PATH=/root/trung_dev

echo 🚀 Deploying Chat Backend to Remote Server...

REM Check if pscp and plink are available (PuTTY tools)
where pscp >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ pscp (PuTTY) is not installed. Please install PuTTY tools first.
    echo Download from: https://www.putty.org/
    pause
    exit /b 1
)

where plink >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ plink (PuTTY) is not installed. Please install PuTTY tools first.
    echo Download from: https://www.putty.org/
    pause
    exit /b 1
)

echo 📦 Preparing backend files for deployment...

REM Create temporary deployment directory
set TEMP_DIR=%TEMP%\backend_deploy
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo 📁 Copying backend files...
xcopy "backend\*" "%TEMP_DIR%\" /E /I /H /Y /EXCLUDE:deploy-exclude.txt

REM Create exclude file for xcopy
echo node_modules\ > deploy-exclude.txt
echo uploads\ >> deploy-exclude.txt
echo .git\ >> deploy-exclude.txt
echo *.log >> deploy-exclude.txt

REM Create production environment file
echo ⚙️ Creating production .env file...
(
echo # Production Environment for Remote Server
echo NODE_ENV=production
echo PORT=5000
echo.
echo # Remote MongoDB Connection
echo MONGODB_URI=mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2ee?authSource=chate2ee
echo.
echo # JWT Secret (Change this in production!^)
echo JWT_SECRET=prod-super-secret-jwt-key-change-me-%RANDOM%
echo.
echo # File Upload Settings
echo UPLOAD_DIR=/app/uploads
echo MAX_FILE_SIZE=104857600
echo MAX_AVATAR_SIZE=2097152
echo.
echo # CORS Configuration
echo CORS_ORIGIN=*
echo.
echo # API Rate Limiting
echo API_RATE_LIMIT=100
echo AUTH_RATE_LIMIT=10
echo.
echo # Logging
echo LOG_LEVEL=info
) > "%TEMP_DIR%\.env"

echo 🔗 Connecting to remote server and setting up...

REM Create remote directory
echo 📁 Creating deployment directory on server...
plink -ssh -pw "%PASSWORD%" %USER%@%SERVER% "mkdir -p /root/trung_dev"

REM Stop existing containers if running
echo 🛑 Stopping existing containers...
plink -ssh -pw "%PASSWORD%" %USER%@%SERVER% "cd /root/trung_dev && if [ -f docker-compose.yml ]; then docker-compose down; fi"

echo 📤 Uploading backend files to server...
pscp -pw "%PASSWORD%" -r "%TEMP_DIR%\*" %USER%@%SERVER%:%REMOTE_PATH%/

echo 🐳 Starting Docker services on remote server...
plink -ssh -pw "%PASSWORD%" %USER%@%SERVER% -m deploy-commands.txt

REM Create commands file for plink
(
echo cd /root/trung_dev
echo.
echo echo "🔍 Checking Docker installation..."
echo if ! command -v docker ^&^> /dev/null; then
echo     echo "❌ Docker is not installed. Please install Docker first."
echo     exit 1
echo fi
echo.
echo if ! command -v docker-compose ^&^> /dev/null; then
echo     echo "❌ Docker Compose is not installed. Please install Docker Compose first."
echo     exit 1
echo fi
echo.
echo echo "✅ Docker is available"
echo.
echo # Create uploads directory
echo mkdir -p uploads/avatars
echo chmod -R 755 uploads
echo.
echo echo "🐳 Starting Docker services..."
echo docker-compose up --build -d
echo.
echo echo "⏳ Waiting for services to start..."
echo sleep 20
echo.
echo echo "🔍 Checking service health..."
echo for i in {1..30}; do
echo     if curl -f http://localhost:5000/health ^> /dev/null 2^>^&1; then
echo         echo "✅ Backend is ready!"
echo         break
echo     fi
echo     if [ $i -eq 30 ]; then
echo         echo "❌ Backend failed to start. Checking logs..."
echo         docker-compose logs backend
echo         exit 1
echo     fi
echo     echo "⏳ Waiting for backend... ($i/30^)"
echo     sleep 2
echo done
echo.
echo echo "🌱 Seeding database..."
echo docker-compose exec -T backend npm run seed
echo.
echo echo ""
echo echo "🎉 Backend deployed successfully!"
echo echo ""
echo echo "🔧 Backend API: http://%SERVER%:5000"
echo echo "📚 API Docs: http://%SERVER%:5000/api/docs"
echo echo "🗄️ MongoDB: Local MongoDB on server"
echo echo ""
echo echo "📋 Useful commands on server:"
echo echo "  cd /root/trung_dev"
echo echo "  docker-compose logs -f                 # View logs"
echo echo "  docker-compose restart                 # Restart services"
echo echo "  docker-compose down                    # Stop services"
echo echo "  docker-compose exec backend sh         # Backend shell"
echo echo ""
) > deploy-commands.txt

REM Cleanup
del deploy-exclude.txt
del deploy-commands.txt
rmdir /s /q "%TEMP_DIR%"

echo.
echo 🎉 Deployment completed!
echo.
echo 🌐 Your backend is now running at: http://%SERVER%:5000
echo 📚 API Documentation: http://%SERVER%:5000/api/docs
echo.
echo 🔧 To manage the deployment:
echo   Use PuTTY to connect to %SERVER%
echo   cd /root/trung_dev
echo   docker-compose logs -f
echo.
pause
