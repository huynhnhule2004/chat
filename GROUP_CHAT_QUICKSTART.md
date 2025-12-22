# 🚀 GROUP CHAT QUICK START GUIDE

## ⚡ Quick Testing (Backend Ready)

### 1. Start Backend Server
```bash
cd backend
npm run dev
```

Expected output:
```
✓ MongoDB connected
✓ Server running on port 5000
✓ Socket.IO initialized
```

### 2. Test API with curl/Postman

#### Create a Password-Protected Group
```bash
curl -X POST http://localhost:5000/api/groups/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "Test Group",
    "password": "test123",
    "initialMembers": ["user1_id", "user2_id"],
    "encryptedSessionKeys": [
      {
        "userId": "user1_id",
        "encryptedKey": "base64_encrypted_key_for_user1"
      },
      {
        "userId": "user2_id",
        "encryptedKey": "base64_encrypted_key_for_user2"
      }
    ]
  }'
```

#### Join Group with Password
```bash
curl -X POST http://localhost:5000/api/groups/join \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "roomId": "ROOM_ID",
    "password": "test123",
    "encryptedSessionKey": "encrypted_key_for_this_user"
  }'
```

#### Get User's Groups
```bash
curl -X GET http://localhost:5000/api/groups \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 3. Test Socket Events

Connect to Socket.IO:
```javascript
const socket = io('http://localhost:5000', {
  auth: { token: 'YOUR_JWT_TOKEN' }
});

// Join group room
socket.emit('join_group', { roomId: 'ROOM_ID' });

// Send group message
socket.emit('send_group_message', {
  roomId: 'ROOM_ID',
  content: 'base64_encrypted_content',
  iv: 'base64_iv',
  authTag: 'base64_auth_tag',
  messageType: 'text'
});

// Listen for messages
socket.on('receive_group_message', (data) => {
  console.log('Received:', data);
});
```

---

## 🔐 Session Key Encryption Example (Node.js)

```javascript
const GroupKeyService = require('./backend/services/groupKeyService');

// 1. Generate Session Key
const sessionKey = GroupKeyService.generateSessionKey();
console.log('Session Key:', sessionKey);
// Output: "a3F2kL8pQw..." (32 bytes base64)

// 2. Encrypt for a user
const userPublicKey = `-----BEGIN RSA PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END RSA PUBLIC KEY-----`;

const encryptedKey = GroupKeyService.encryptSessionKey(sessionKey, userPublicKey);
console.log('Encrypted:', encryptedKey);
// Output: "x8KmL3pNq..." (RSA-OAEP encrypted, base64)

// 3. Encrypt for multiple members
const memberIds = ['user1', 'user2', 'user3'];
const encryptedKeys = await GroupKeyService.encryptSessionKeyForMembers(
  sessionKey, 
  memberIds
);
console.log('Encrypted Keys:', encryptedKeys);
// Output: [
//   { userId: 'user1', encryptedKey: 'abc...', publicKey: '...' },
//   { userId: 'user2', encryptedKey: 'def...', publicKey: '...' },
//   { userId: 'user3', encryptedKey: 'ghi...', publicKey: '...' }
// ]
```

---

## 📊 Database Verification Queries

### Check Room Created
```javascript
// MongoDB Shell
use your_database;

db.rooms.findOne({ name: "Test Group" });
// Expected:
{
  _id: ObjectId("..."),
  name: "Test Group",
  passwordHash: "$2a$10$...",  // ✅ bcrypt hash
  isPasswordProtected: true,
  sessionKeyVersion: 1,
  members: ["admin_id", "user1_id", "user2_id"],
  memberCount: 3
}
```

### Check RoomMembers Created
```javascript
db.roommembers.find({ roomId: ObjectId("ROOM_ID") });
// Expected: 3 entries (admin + 2 members)
// Each with DIFFERENT encryptedSessionKey
[
  {
    userId: "admin_id",
    encryptedSessionKey: "x8KmL3...",  // Unique for admin
    sessionKeyVersion: 1,
    role: "owner"
  },
  {
    userId: "user1_id",
    encryptedSessionKey: "p9NqW7...",  // Unique for user1
    sessionKeyVersion: 1,
    role: "member"
  },
  {
    userId: "user2_id",
    encryptedSessionKey: "k2BfT9...",  // Unique for user2
    sessionKeyVersion: 1,
    role: "member"
  }
]
```

### Check Message Encrypted
```javascript
db.messages.findOne({ roomId: ObjectId("ROOM_ID") });
// Expected:
{
  sender: "user1_id",
  roomId: "ROOM_ID",
  content: "encrypted_base64",  // ✅ NOT plaintext
  iv: "random_iv",
  authTag: "auth_tag",
  messageType: "text",
  timestamp: Date
}
```

---

## 🎯 Testing Checklist

### Backend Tests
- [ ] **Create group with password**
  - Password stored as bcrypt hash ✅
  - RoomMember entries created with encrypted keys ✅
  - sessionKeyVersion = 1 ✅

- [ ] **Join group - correct password**
  - User added to members[] ✅
  - Returns user's encrypted session key ✅

- [ ] **Join group - wrong password**
  - Returns 401 Unauthorized ✅
  - Error: "Incorrect password" ✅

- [ ] **Send group message**
  - Message saved to database (encrypted) ✅
  - Broadcasted to all members in room ✅

- [ ] **Kick member**
  - Member removed from room ✅
  - RoomMember.isActive = false ✅
  - sessionKeyVersion incremented ✅
  - Remaining members' keys updated ✅

### Security Tests
- [ ] **Password never stored plaintext**
  - Check Room.passwordHash is bcrypt hash ✅

- [ ] **Session Key never stored on server**
  - Only encrypted copies in RoomMember ✅

- [ ] **Each member has unique encrypted copy**
  - Query RoomMembers: all encryptedSessionKey different ✅

- [ ] **Kicked member can't decrypt new messages**
  - Try decrypting with old key: fails ✅

---

## 🐛 Troubleshooting

### Error: "User does not have a public key"
**Cause**: User hasn't registered RSA key pair yet.

**Solution**: Make sure User model has `publicKey` field populated during registration.

```javascript
// Check user
db.users.findOne({ _id: "USER_ID" });
// Expected:
{
  username: "john_doe",
  publicKey: "-----BEGIN RSA PUBLIC KEY-----\n..."  // ✅ Must exist
}
```

### Error: "Encrypted session keys are required"
**Cause**: Client didn't provide `encryptedSessionKeys` array in create group request.

**Solution**: Admin must encrypt Session Key for each member BEFORE calling API:

```javascript
// Client side (Flutter)
final sessionKey = await GroupKeyService.generateSessionKey();
final encryptedKeys = await encryptForMembers(sessionKey, memberIds);

// Then send to API
await api.createGroup({ ..., encryptedSessionKeys: encryptedKeys });
```

### Error: "Failed to encrypt session key"
**Cause**: Invalid public key format or crypto error.

**Solution**: Check public key is valid PEM format:
```
-----BEGIN RSA PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END RSA PUBLIC KEY-----
```

### Socket not receiving messages
**Cause**: User didn't join socket room.

**Solution**: Emit `join_group` BEFORE sending messages:
```javascript
socket.emit('join_group', { roomId: 'ROOM_ID' });
// Wait for server acknowledgment
setTimeout(() => {
  socket.emit('send_group_message', { ... });
}, 500);
```

---

## 📚 Documentation Files

- **[GROUP_CHAT_GUIDE.md](GROUP_CHAT_GUIDE.md)** - Complete technical guide (security model, flows, API docs)
- **[GROUP_CHAT_SUMMARY.md](GROUP_CHAT_SUMMARY.md)** - Implementation summary (what's done, what's next)
- **This file** - Quick start for testing backend

---

## 🔗 Related Guides

- **[FORWARD_MESSAGE_GUIDE.md](FORWARD_MESSAGE_GUIDE.md)** - Forward message feature (1-1 chat)
- **[FORWARD_TESTING_GUIDE.md](FORWARD_TESTING_GUIDE.md)** - Testing forward messages
- **[AUTH_USER_MANAGEMENT_GUIDE.md](AUTH_USER_MANAGEMENT_GUIDE.md)** - User registration with RSA keys

---

## 🚀 Next Steps

1. **Test Backend**: Use curl/Postman to test all endpoints
2. **Implement Flutter GroupKeyService**: RSA encryption/decryption on client
3. **Build UI Screens**: CreateGroupScreen, JoinGroupDialog, GroupListScreen, GroupChatScreen
4. **Integrate Sockets**: Connect Flutter to group socket events
5. **End-to-End Test**: Create group → Join → Send messages → Kick member → Verify security

---

**Backend Status**: ✅ Complete  
**Frontend Status**: 🚧 In Progress (70%)  
**Documentation**: ✅ Complete
