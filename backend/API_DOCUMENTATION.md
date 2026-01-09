# E2EE Chat API Documentation

## Overview
This is a comprehensive End-to-End Encrypted (E2EE) Chat Application API built with Node.js, Express, Socket.io, and MongoDB. The API supports real-time messaging, group chats, file sharing, and user management with strong encryption.

## Features
- **End-to-End Encryption**: All messages are encrypted on client-side using RSA and AES
- **Real-time Communication**: Socket.io for instant messaging
- **Group Chats**: Create and manage encrypted group conversations
- **File Sharing**: Upload and share files with encryption
- **User Management**: Registration, authentication, and profile management
- **Avatar Support**: Upload and manage user avatars

## Authentication
The API uses JWT (JSON Web Tokens) for authentication. Include the token in the Authorization header:
```
Authorization: Bearer <your-jwt-token>
```

## API Documentation
Interactive API documentation is available at: `http://localhost:5000/api/docs`

### Export Options
- **Swagger JSON**: `http://localhost:5000/api/docs/swagger.json`
- **Swagger YAML**: `http://localhost:5000/api/docs/swagger.yaml`
- **Postman Collection**: Import the JSON spec into Postman for testing

## Security Architecture

### Encryption Flow
1. **User Registration**: Each user generates an RSA key pair (public/private keys)
2. **Direct Messages**: Messages encrypted with recipient's public key
3. **Group Messages**: 
   - Group admin generates a session key (AES-256)
   - Session key is encrypted with each member's RSA public key
   - Messages are encrypted with the session key
   - Key rotation on member changes

### Password Protection
- Groups can be password-protected using bcrypt hashing
- Passwords are validated server-side but don't affect E2EE

## Main API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user

### Users
- `GET /api/users/search` - Search users
- `GET /api/users/:userId/public-key` - Get user's public key

### Messages
- `GET /api/messages` - Get all conversations
- `GET /api/messages/:userId` - Get messages with specific user

### Groups
- `POST /api/groups/create` - Create new group
- `POST /api/groups/join` - Join existing group
- `GET /api/groups` - Get user's groups
- `GET /api/groups/:roomId/messages` - Get group messages
- `POST /api/groups/:roomId/add-member` - Add member to group
- `POST /api/groups/:roomId/kick` - Remove member from group
- `POST /api/groups/:roomId/leave` - Leave group
- `DELETE /api/groups/:roomId` - Delete group

### Files
- `POST /api/files/upload` - Upload file (max 100MB)

### Profile
- `GET /api/profile/me` - Get current user profile
- `POST /api/profile/upload-avatar` - Upload avatar (max 2MB)

## Socket.io Events

### Client Events
- `join_room` - Join a room for real-time updates
- `send_message` - Send encrypted message
- `typing_start` - Start typing indicator
- `typing_stop` - Stop typing indicator

### Server Events
- `new_message` - Receive new encrypted message
- `user_joined` - User joined room
- `user_left` - User left room
- `typing` - Someone is typing
- `message_read` - Message read status update

## Error Handling
All endpoints return consistent error responses:
```json
{
  "error": "Error message describing what went wrong"
}
```

Common HTTP status codes:
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (access denied)
- `404` - Not Found
- `500` - Internal Server Error

## Rate Limiting
- File uploads: 100MB max size
- Avatar uploads: 2MB max size
- Message history: 50 messages per request (paginated)

## Database Models

### User
- Username, email, password (hashed)
- RSA public key for E2EE
- Avatar, online status, last active

### Room
- Group chat information
- Owner, members, password hash
- Session key version for encryption

### Message
- Encrypted content, sender, recipient/room
- File attachments, timestamps
- Read status, message type

### RoomMember
- User membership in groups
- Encrypted session keys
- Roles (owner, admin, member)

## Development Setup
1. Install dependencies: `npm install`
2. Set up MongoDB connection
3. Configure environment variables
4. Run: `npm start` or `npm run dev`
5. Access API docs: `http://localhost:5000/api/docs`
6. Export API spec: 
   - JSON: `http://localhost:5000/api/docs/swagger.json`
   - YAML: `http://localhost:5000/api/docs/swagger.yaml`

## Environment Variables
```env
PORT=5000
MONGODB_URI=mongodb://localhost:27017/e2ee_chat
JWT_SECRET=your_jwt_secret_key
NODE_ENV=development
```

## Testing
- API testing: `npm run test:api`
- Use test files in `/test` directory
- Postman collection available for API testing

## Production Considerations
- Use HTTPS in production
- Configure CORS properly
- Set up proper MongoDB indexing
- Use environment-specific configurations
- Enable rate limiting
- Set up monitoring and logging
