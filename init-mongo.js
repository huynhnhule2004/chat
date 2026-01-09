// MongoDB initialization script
print('Starting MongoDB initialization...');

// Create application database
db = db.getSiblingDB('chatapp');

// Create application user with read/write permissions
db.createUser({
  user: 'chatapp_user',
  pwd: 'chatapp_password',
  roles: [
    {
      role: 'readWrite',
      db: 'chatapp'
    }
  ]
});

// Create collections with indexes
db.createCollection('users');
db.createCollection('messages');
db.createCollection('rooms');
db.createCollection('roommembers');

// Create indexes for better performance
db.users.createIndex({ "username": 1 }, { unique: true });
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "isOnline": 1 });

db.messages.createIndex({ "senderId": 1 });
db.messages.createIndex({ "recipientId": 1 });
db.messages.createIndex({ "roomId": 1 });
db.messages.createIndex({ "timestamp": -1 });
db.messages.createIndex({ "senderId": 1, "recipientId": 1, "timestamp": -1 });

db.rooms.createIndex({ "ownerId": 1 });
db.rooms.createIndex({ "members": 1 });
db.rooms.createIndex({ "name": "text", "description": "text" });

db.roommembers.createIndex({ "roomId": 1, "userId": 1 }, { unique: true });
db.roommembers.createIndex({ "userId": 1 });

print('MongoDB initialization completed successfully!');
print('Database: chatapp');
print('Collections created: users, messages, rooms, roommembers');
print('Indexes created for optimal performance');
print('Application user: chatapp_user created');
