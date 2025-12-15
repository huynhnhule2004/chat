# End-to-End Encrypted Chat Application

A secure chat application with end-to-end encryption (E2EE) built with Flutter (frontend) and Node.js (backend).

## Features

- 🔐 **End-to-End Encryption**: Messages encrypted with AES-256-GCM
- 🔑 **ECDH Key Exchange**: Secure key exchange using Elliptic Curve Diffie-Hellman
- 💬 **Real-time Messaging**: Socket.io for instant message delivery
- 💾 **Local Storage**: SQLite for offline message storage
- 📁 **Media Support**: Image, video, and file sharing
- 🎥 **Video Streaming**: HTTP Range requests for efficient video playback
- ⚡ **Message Limit**: Server automatically cleans old messages to save space
- 🔒 **JWT Authentication**: Secure user authentication

## Architecture

### Backend (Node.js)
- Express.js for REST API
- Socket.io for real-time communication
- MongoDB for temporary message storage
- Multer for file uploads
- JWT for authentication

### Frontend (Flutter)
- SQLite (sqflite) for local message storage
- Cryptography package for E2EE
- Socket.io client for real-time updates
- Dio for HTTP requests
- Provider for state management

## How E2EE Works

1. **Registration**: User generates ECDH key pair (Public/Private)
2. **Key Storage**: Private key stored securely on device, Public key sent to server
3. **Starting Chat**: 
   - Alice gets Bob's public key from server
   - Alice computes shared secret: `sharedKey = ECDH(Alice_Private, Bob_Public)`
   - Bob computes the same: `sharedKey = ECDH(Bob_Private, Alice_Public)`
4. **Sending Message**:
   - Encrypt with AES-256-GCM using shared key
   - Send encrypted text to server
   - Server stores and forwards encrypted message (cannot read content)
5. **Receiving Message**:
   - Decrypt with shared key
   - Store decrypted message in local SQLite

## Setup Instructions

### Prerequisites

- Node.js (v18+)
- MongoDB (v6+)
- Flutter SDK (v3.10+)
- Android Studio / Xcode (for mobile development)

### Backend Setup

1. Navigate to backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env` file (already created):
```env
PORT=3000
MONGODB_URI=mongodb://localhost:27017/e2ee_chat
JWT_SECRET=your_jwt_secret_key_change_this_in_production
MESSAGE_LIMIT=1000
```

4. Start MongoDB:
```bash
# Windows (if installed as service)
net start MongoDB

# Or using mongod
mongod --dbpath C:\data\db
```

5. Start server:
```bash
npm start

# Or for development with auto-reload
npm run dev
```

Server will run on `http://localhost:3000`

### Flutter Setup

1. Navigate to flutter directory:
```bash
cd flutter
```

2. Install dependencies:
```bash
flutter pub get
```

3. Update server URL in `lib/config/app_config.dart` if needed:
```dart
static const String baseUrl = 'http://localhost:3000';
```

For Android emulator, use: `http://10.0.2.2:3000`
For iOS simulator, use: `http://localhost:3000`
For physical device, use your computer's IP: `http://192.168.x.x:3000`

4. Run the app:
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Or just run (will prompt for device)
flutter run
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user

### Users
- `GET /api/users/:userId/public-key` - Get user's public key
- `GET /api/users/search?query=username` - Search users

### Messages
- `GET /api/messages/:userId` - Get messages with user
- `GET /api/messages` - Get all conversations

### Files
- `POST /api/files/upload` - Upload file
- `GET /api/files/:filename` - Download file
- `GET /api/files/video/:filename` - Stream video

## Socket.io Events

### Client -> Server
- `join_room` - Join conversation room
- `send_message` - Send message
- `typing` - Send typing indicator

### Server -> Client
- `receive_message` - New message received
- `user_typing` - User typing status
- `user_online` - User came online
- `user_offline` - User went offline
- `new_message_notification` - New message notification

## Project Structure

### Backend
```
backend/
├── config/
│   └── db.js              # MongoDB connection
├── middleware/
│   └── auth.js            # JWT authentication
├── models/
│   ├── User.js            # User schema (includes publicKey)
│   └── Message.js         # Message schema (encrypted content)
├── routes/
│   ├── auth.js            # Auth endpoints
│   ├── users.js           # User endpoints
│   ├── messages.js        # Message endpoints
│   └── files.js           # File upload/download
├── services/
│   ├── messageService.js  # Message logic with auto-cleanup
│   └── socketService.js   # Socket.io handlers
├── server.js              # Main server file
└── package.json
```

### Flutter
```
flutter/lib/
├── config/
│   └── app_config.dart      # App configuration
├── database/
│   └── database_helper.dart # SQLite helper
├── models/
│   ├── user.dart            # User model
│   ├── message.dart         # Message model
│   └── conversation.dart    # Conversation model
├── providers/
│   └── chat_provider.dart   # State management
├── screens/
│   ├── login_screen.dart         # Login/Register UI
│   ├── conversations_screen.dart # Conversation list
│   └── chat_screen.dart          # Chat UI
├── services/
│   ├── api_service.dart      # REST API client
│   ├── socket_service.dart   # Socket.io client
│   └── crypto_service.dart   # E2EE cryptography
└── main.dart                 # App entry point
```

## Security Notes

⚠️ **Important for Production:**

1. Change `JWT_SECRET` in `.env` to a strong random string
2. Update CORS settings in `server.js` to allow only your frontend domain
3. Use HTTPS in production (not HTTP)
4. Consider implementing rate limiting
5. Add input validation and sanitization
6. Implement password strength requirements
7. Add 2FA for enhanced security
8. Use secure storage for encryption keys

## Message Limit Logic

The server automatically manages storage by:
- Limiting messages per conversation (default: 1000)
- Auto-deleting oldest messages when limit exceeded
- Client stores full history in SQLite
- Server acts as temporary relay, not permanent storage

To change limit, update `MESSAGE_LIMIT` in `.env`

## Testing

### Test Backend API
```bash
# Test health check
curl http://localhost:3000/health

# Test registration
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123","publicKey":"test_public_key"}'
```

### Test Flutter App
1. Run app on two devices/emulators
2. Register two different users
3. Search for each other
4. Start chatting
5. Test file upload
6. Test video streaming

## Troubleshooting

### Backend Issues

**MongoDB connection error:**
- Ensure MongoDB is running
- Check connection string in `.env`
- Verify MongoDB port (default: 27017)

**Socket connection error:**
- Check firewall settings
- Verify CORS configuration
- Ensure JWT token is valid

### Flutter Issues

**Cannot connect to server:**
- Update `baseUrl` in `app_config.dart` with correct IP
- For Android emulator: use `10.0.2.2` instead of `localhost`
- Check if backend server is running

**Encryption errors:**
- Ensure both users have registered properly
- Check if public keys are stored
- Verify shared key computation

**Database errors:**
- Clear app data and reinstall
- Check SQLite permissions

## Future Enhancements

- [ ] Group chats
- [ ] Voice/Video calls (WebRTC)
- [ ] Message reactions
- [ ] Read receipts
- [ ] Push notifications
- [ ] Backup/Restore to cloud
- [ ] Desktop apps (Windows, Mac, Linux)
- [ ] Message search
- [ ] Profile pictures
- [ ] Status updates

## License

MIT License

## Contributing

Pull requests are welcome! Please ensure:
1. Code follows existing style
2. All tests pass
3. New features include tests
4. Security best practices followed

## Support

For issues and questions, please create an issue on the repository.
