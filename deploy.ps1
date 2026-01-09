# PowerShell deployment script for Windows
Write-Host "Rocket Windows PowerShell Deployment Script" -ForegroundColor Green
Write-Host "Server: 146.190.194.170" -ForegroundColor Cyan
Write-Host "User: root" -ForegroundColor Cyan
Write-Host "Password: phNlSQmZWAqm" -ForegroundColor Cyan
Write-Host ""

# Check if package exists
$packagePath = "backend-deploy.tar.gz"
if (Test-Path $packagePath) {
    $size = (Get-Item $packagePath).Length / 1KB
    Write-Host "Package found: $packagePath ($([math]::Round($size, 2)) KB)" -ForegroundColor Green
} else {
    Write-Host "Package not found. Run deploy-manual.sh first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Testing server connectivity..." -ForegroundColor Yellow

# Test connection using PowerShell's built-in Test-NetConnection (Windows 10+)
try {
    $connection = Test-NetConnection -ComputerName "146.190.194.170" -Port 22 -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        Write-Host "Port 22 is accessible" -ForegroundColor Green
    } else {
        Write-Host "Port 22 is not accessible" -ForegroundColor Red
    }
} catch {
    Write-Host "Connection test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Manual deployment instructions:" -ForegroundColor Yellow
Write-Host "Since SSH is not working, please use one of these methods:" -ForegroundColor White

Write-Host ""
Write-Host "Method 1 - Using Windows SSH (if working):" -ForegroundColor Cyan
Write-Host "ssh root@146.190.194.170" -ForegroundColor White
Write-Host "Password: phNlSQmZWAqm" -ForegroundColor White

Write-Host ""
Write-Host "Method 2 - Using PuTTY:" -ForegroundColor Cyan
Write-Host "1. Open PuTTY" -ForegroundColor White
Write-Host "2. Host: 146.190.194.170" -ForegroundColor White
Write-Host "3. Port: 22" -ForegroundColor White
Write-Host "4. Username: root" -ForegroundColor White
Write-Host "5. Password: phNlSQmZWAqm" -ForegroundColor White

Write-Host ""
Write-Host "Method 3 - Using WinSCP/FileZilla:" -ForegroundColor Cyan
Write-Host "1. Upload backend-deploy.tar.gz to /root/trung_dev/" -ForegroundColor White
Write-Host "2. Connect via SSH terminal" -ForegroundColor White

Write-Host ""
Write-Host "Commands to run on server:" -ForegroundColor Yellow
Write-Host @"
mkdir -p /root/trung_dev
cd /root/trung_dev
tar -xzf backend-deploy.tar.gz

cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb://chate2ee_user:ChatE2EEPass123!@127.0.0.1:27017/chate2ee?authSource=chate2ee
JWT_SECRET=prod-super-secret-jwt-key-change-me-123
UPLOAD_DIR=/app/uploads
MAX_FILE_SIZE=104857600
MAX_AVATAR_SIZE=2097152
CORS_ORIGIN=*
API_RATE_LIMIT=100
AUTH_RATE_LIMIT=10
LOG_LEVEL=info
EOF

mkdir -p uploads/avatars
chmod -R 755 uploads
docker-compose up --build -d
sleep 20
docker-compose exec -T backend npm run seed

# Test
curl http://localhost:5000/health
curl http://localhost:5000/api/docs
"@ -ForegroundColor White

Write-Host ""
Write-Host "After successful deployment, access:" -ForegroundColor Green
Write-Host "API: http://146.190.194.170:5000" -ForegroundColor White
Write-Host "Swagger Docs: http://146.190.194.170:5000/api/docs" -ForegroundColor White
Write-Host "Health Check: http://146.190.194.170:5000/health" -ForegroundColor White
