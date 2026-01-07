#!/bin/bash

echo "========================================="
echo "MongoDB Installation Script"
echo "========================================="

# Update system
echo "Updating system packages..."
apt-get update

# Install required dependencies
echo "Installing dependencies..."
apt-get install -y gnupg curl

# Import MongoDB public GPG key
echo "Importing MongoDB GPG key..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "Adding MongoDB repository..."
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
   tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Update package database
echo "Updating package database..."
apt-get update

# Install MongoDB
echo "Installing MongoDB..."
apt-get install -y mongodb-org

# Start MongoDB service
echo "Starting MongoDB service..."
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to start
sleep 5

# Check MongoDB status
echo "Checking MongoDB status..."
systemctl status mongod --no-pager

# Configure MongoDB for remote access
echo "Configuring MongoDB for remote access..."
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

# Restart MongoDB
echo "Restarting MongoDB..."
systemctl restart mongod

sleep 3

# Create admin user and database
echo "Creating MongoDB users and database..."
mongosh <<EOF
use admin

db.createUser({
  user: "adminUser",
  pwd: "StrongAdminPassword123!",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
})

use chate2ee

db.createUser({
  user: "chate2ee_user",
  pwd: "ChatE2EEPass123!",
  roles: [ { role: "readWrite", db: "chate2ee" } ]
})

exit
EOF

# Enable authentication
echo "Enabling authentication..."
cat >> /etc/mongod.conf <<EOF

security:
  authorization: enabled
EOF

# Restart MongoDB with authentication
echo "Restarting MongoDB with authentication..."
systemctl restart mongod

sleep 3

# Configure firewall if UFW is active
if systemctl is-active --quiet ufw; then
    echo "Configuring firewall..."
    ufw allow 27017/tcp
    ufw reload
fi

echo "========================================="
echo "MongoDB Installation Complete!"
echo "========================================="
echo "Database: chate2ee"
echo "User: chate2ee_user"
echo "Password: ChatE2EEPass123!"
echo "Connection String:"
echo "mongodb://chate2ee_user:ChatE2EEPass123!@146.190.194.170:27017/chate2ee?authSource=chate2ee"
echo "========================================="
