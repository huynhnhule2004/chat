// MongoDB initialization script for Backend
print('Starting MongoDB initialization for Chat Backend...');

// Get database name from environment or use default
const dbName = process.env.MONGO_INITDB_DATABASE || 'chatapp';
db = db.getSiblingDB(dbName);

// Create application user with read/write permissions
db.createUser({
  user: 'chatapp_user',
  pwd: 'chatapp_password',
  roles: [
    {
      role: 'readWrite',
      db: dbName
    }
  ]
});

// Create collections
print('Creating collections...');
db.createCollection('users');
db.createCollection('messages');
db.createCollection('rooms');
db.createCollection('roommembers');

// Create indexes for better performance
print('Creating indexes...');

// Users collection indexes
db.users.createIndex({ "username": 1 }, { unique: true });
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "isOnline": 1 });
db.users.createIndex({ "role": 1 });
db.users.createIndex({ "createdAt": -1 });

// Messages collection indexes
db.messages.createIndex({ "senderId": 1 });
db.messages.createIndex({ "recipientId": 1 });
db.messages.createIndex({ "roomId": 1 });
db.messages.createIndex({ "timestamp": -1 });
db.messages.createIndex({ "messageType": 1 });
db.messages.createIndex({ "isRead": 1 });
// Compound indexes for common queries
db.messages.createIndex({ "senderId": 1, "recipientId": 1, "timestamp": -1 });
db.messages.createIndex({ "roomId": 1, "timestamp": -1 });

// Rooms collection indexes
db.rooms.createIndex({ "ownerId": 1 });
db.rooms.createIndex({ "members": 1 });
db.rooms.createIndex({ "isPasswordProtected": 1 });
db.rooms.createIndex({ "createdAt": -1 });
db.rooms.createIndex({ "lastActivity": -1 });
// Text search index for room name and description
db.rooms.createIndex({ "name": "text", "description": "text" });

// Room members collection indexes
db.roommembers.createIndex({ "roomId": 1, "userId": 1 }, { unique: true });
db.roommembers.createIndex({ "userId": 1 });
db.roommembers.createIndex({ "role": 1 });
db.roommembers.createIndex({ "joinedAt": -1 });

// Create compound index for room member queries
db.roommembers.createIndex({ "roomId": 1, "role": 1 });

print('MongoDB initialization completed successfully!');
print('Database: ' + dbName);
print('Collections created: users, messages, rooms, roommembers');
print('Indexes created for optimal performance');
print('Application user: chatapp_user created');

// Show collection stats
print('\n=== Collection Statistics ===');
print('Users: ' + db.users.countDocuments());
print('Messages: ' + db.messages.countDocuments());
print('Rooms: ' + db.rooms.countDocuments());
print('RoomMembers: ' + db.roommembers.countDocuments());
print('==============================');
