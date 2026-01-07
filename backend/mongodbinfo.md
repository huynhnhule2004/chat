# MongoDB Server Information

## Server Details
- **Server IP**: 146.190.194.170
- **SSH User**: root
- **SSH Password**: phNlSQmZWAqm

## Installation Steps

### 1. Connect to Server
```bash
ssh root@146.190.194.170
# Password: phNlSQmZWAqm
```

### 2. Install MongoDB on Ubuntu/Debian
```bash
# Import MongoDB public GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
   sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package database
sudo apt-get update

# Install MongoDB
sudo apt-get install -y mongodb-org

# Start MongoDB service
sudo systemctl start mongod
sudo systemctl enable mongod

# Check status
sudo systemctl status mongod
```

### 3. Configure MongoDB for Remote Access
```bash
# Edit MongoDB configuration
sudo nano /etc/mongod.conf

# Change bindIp to allow remote connections:
# net:
#   port: 27017
#   bindIp: 0.0.0.0

# Restart MongoDB
sudo systemctl restart mongod
```

### 4. Create Database and User
```bash
# Connect to MongoDB shell
mongosh

# In MongoDB shell, run these commands:
use admin

# Create admin user
db.createUser({
  user: "adminUser",
  pwd: "StrongAdminPassword123!",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
})

# Create database and user for chate2ee
use chate2ee

db.createUser({
  user: "chate2ee_user",
  pwd: "ChatE2EEPass123!",
  roles: [ { role: "readWrite", db: "chate2ee" } ]
})

# Exit MongoDB shell
exit
```

### 5. Enable Authentication
```bash
# Edit MongoDB configuration
sudo nano /etc/mongod.conf

# Enable authentication by adding:
# security:
#   authorization: enabled

# Restart MongoDB
sudo systemctl restart mongod
```

### 6. Configure Firewall (if UFW is enabled)
```bash
# Allow MongoDB port
sudo ufw allow 27017/tcp
sudo ufw reload
```

## Database Connection Information

### Database Details
- **Database Name**: chate2ee
- **Host**: 146.190.194.170
- **Port**: 27017

### Admin User
- **Username**: adminUser
- **Password**: StrongAdminPassword123!
- **Auth Database**: admin

### Application User
- **Username**: chate2ee_user
- **Password**: ChatE2EEPass123!
- **Auth Database**: chate2ee

### MongoDB Connection Strings

**For Application (chate2ee database):**
```
mongodb://chate2ee_user:ChatE2EEPass123!@146.190.194.170:27017/chate2ee?authSource=chate2ee
```

**For Admin Access:**
```
mongodb://adminUser:StrongAdminPassword123!@146.190.194.170:27017/admin?authSource=admin
```

## Backend Configuration

Update your `backend/config/db.js` with:
```javascript
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://chate2ee_user:ChatE2EEPass123!@146.190.194.170:27017/chate2ee?authSource=chate2ee';
```

## Security Notes
⚠️ **Important**: 
- Change the default passwords above to strong, unique passwords
- Consider using environment variables for sensitive credentials
- Ensure firewall rules are properly configured
- Enable SSL/TLS for production use
- Regularly backup your database

## Useful Commands

### Check MongoDB Status
```bash
sudo systemctl status mongod
```

### View MongoDB Logs
```bash
sudo tail -f /var/log/mongodb/mongod.log
```

### Restart MongoDB
```bash
sudo systemctl restart mongod
```

### Connect to MongoDB Shell
```bash
mongosh "mongodb://chate2ee_user:ChatE2EEPass123!@146.190.194.170:27017/chate2ee?authSource=chate2ee"
```

## Installation Status

✅ **MongoDB successfully installed and configured!**

- **Installation Date**: January 7, 2026
- **MongoDB Version**: 7.0.28
- **Status**: Running and Active
- **Remote Access**: Enabled (bindIp: 0.0.0.0)
- **Authentication**: Enabled
- **Database Created**: chate2ee
- **Users Created**: 
  - adminUser (admin database)
  - chate2ee_user (chate2ee database)

### Verification

Connection test successful:
```bash
mongosh "mongodb://chate2ee_user:ChatE2EEPass123!@146.190.194.170:27017/chate2ee?authSource=chate2ee"
```

Result: ✅ Connected successfully with readWrite permissions

### Next Steps

1. Update backend/config/db.js with the connection string
2. Test the backend application connection
3. Consider changing default passwords for production
4. Set up regular database backups

---
*Last Updated: January 7, 2026*
*Installation Completed: January 7, 2026 09:32 UTC*
