# 🧪 HƯỚNG DẪN TEST TÍNH NĂNG MỚI - CHAT E2EE

## 📋 MỤC LỤC
1. [Test Forward Message (Chuyển tiếp tin nhắn)](#1-test-forward-message)
2. [Test Group Chat (Nhóm chat - Backend)](#2-test-group-chat-backend)
3. [Test E2EE Security](#3-test-e2ee-security)
4. [Test File Upload](#4-test-file-upload)

---

## 1. TEST FORWARD MESSAGE (Chuyển tiếp tin nhắn)

### ✅ Chuẩn bị
```bash
# Tạo 5 user test
cd backend
node test-forward-helper.js
```

**Thông tin user:**
- Email: test_a@test.com đến test_e@test.com
- Password: password123

### 📝 Test Case 1: Forward cơ bản (Text message)

**Bước 1: User B gửi tin nhắn cho User A**
1. Đăng nhập User B (test_b@test.com / password123)
2. Mở chat với User A
3. Gửi tin: "Hello from User B!"

**Bước 2: User A forward cho User C**
1. Đăng xuất, đăng nhập User A (test_a@test.com / password123)
2. Mở chat với User B
3. **Long press (giữ)** tin nhắn "Hello from User B!"
4. Chọn "Forward" trong menu
5. Chọn User C trong danh sách
6. Nhấn nút Forward (biểu tượng ✈️)

**Kết quả mong đợi:**
- ✅ Hiện thông báo "Message forwarded successfully!"
- ✅ User C nhận được tin nhắn

**Bước 3: User C xem tin nhắn đã forward**
1. Đăng xuất, đăng nhập User C
2. Mở chat với User A
3. Xem tin nhắn vừa nhận

**Kết quả mong đợi:**
- ✅ Tin nhắn hiển thị "Hello from User B!"
- ✅ Có badge 🔄 "Forwarded from test_b" phía trên tin nhắn
- ✅ Tin nhắn được mã hóa riêng cho User C (không phải copy gói tin cũ)

---

### 📝 Test Case 2: Forward cho nhiều người cùng lúc

**Bước 1: User A forward tin cho 3 người**
1. Đăng nhập User A
2. Mở chat với User B
3. Long press tin nhắn
4. Chọn Forward
5. **Chọn nhiều người:** User C, User D, User E (tick vào checkbox)
6. Nhấn Forward

**Kết quả mong đợi:**
- ✅ Hiện loading dialog "Forwarding to 3 contacts..."
- ✅ Thông báo "Message forwarded to 3 contacts successfully!"
- ✅ Cả 3 người đều nhận được tin nhắn

**Bước 2: Kiểm tra mã hóa độc lập**
```bash
# Check database
cd flutter
sqlite3 path/to/e2ee_chat.db

# User C nhận được (mã hóa với key của C)
SELECT content FROM messages WHERE receiver_id = 'user_c_id' AND is_forwarded = 1;

# User D nhận được (mã hóa với key của D)
SELECT content FROM messages WHERE receiver_id = 'user_d_id' AND is_forwarded = 1;

# Nội dung encrypted KHÁC NHAU dù cùng plaintext!
```

**Kết quả mong đợi:**
- ✅ Mỗi người nhận có `content` khác nhau (mã hóa riêng)
- ✅ Nhưng khi giải mã đều ra "Hello from User B!"

---

### 📝 Test Case 3: Forward hình ảnh (File Key Wrapping)

**Bước 1: User B gửi hình ảnh cho User A**
1. Đăng nhập User B
2. Mở chat với User A
3. Nhấn 📎 > Chọn hình ảnh (5MB)
4. Gửi

**Bước 2: User A forward hình cho User C**
1. Đăng nhập User A
2. Long press hình ảnh
3. Forward cho User C

**Bước 3: Kiểm tra network (QUAN TRỌNG)**
Mở Chrome DevTools Network tab hoặc check backend logs:

```bash
# Backend logs
cd backend
npm run dev

# Xem logs khi forward
# Mong đợi: CHỈ 1 request nhỏ (~500 bytes), KHÔNG upload lại 5MB!
```

**Kết quả mong đợi:**
- ✅ User C nhận được hình ảnh
- ✅ **Network upload chỉ ~500 bytes** (file key re-wrapped)
- ✅ **KHÔNG upload lại 5MB** (file đã có trên server)
- ✅ User C mở hình được (giải mã thành công với key mới)

**Công thức tính:**
```
Original image: 5MB (5,000,000 bytes)
Forward without re-upload: ~500 bytes (encrypted file key)
Bandwidth saved: 99.99%! ✅
```

---

### 📝 Test Case 4: Forward chain (A → B → C → D)

**Test forward qua nhiều người:**

1. User A gửi: "Original message"
2. User B forward cho User C
3. User C forward cho User D
4. User D forward cho User E

**Kết quả mong đợi tại User E:**
- ✅ Nội dung: "Original message"
- ✅ Badge: "Forwarded from test_a" (giữ người gửi GỐC, không phải test_d)
- ✅ `originalSenderId` = User A ID
- ✅ `forwardedFrom` = "test_a"

---

## 2. TEST GROUP CHAT (Backend - API)

### ✅ Chuẩn bị
```bash
# Start backend server
cd backend
npm run dev

# Lấy JWT token
# Đăng nhập để có token
```

### 📝 Test Case 1: Tạo nhóm có password

**Request (Postman/curl):**
```bash
curl -X POST http://localhost:5000/api/groups/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "name": "Nhóm Test",
    "avatar": "https://example.com/avatar.jpg",
    "description": "Nhóm để test tính năng",
    "password": "matkhau123",
    "initialMembers": [],
    "encryptedSessionKeys": []
  }'
```

**Kết quả mong đợi:**
```json
{
  "message": "Group created successfully",
  "room": {
    "id": "674c5f8a9b...",
    "name": "Nhóm Test",
    "isPasswordProtected": true,
    "sessionKeyVersion": 1,
    "memberCount": 1
  }
}
```

**Kiểm tra database:**
```bash
# MongoDB
mongosh
use your_database
db.rooms.findOne({ name: "Nhóm Test" })

# Expected output:
{
  passwordHash: "$2a$10$...",  // ✅ Mã hóa bcrypt, KHÔNG phải "matkhau123"
  isPasswordProtected: true,
  sessionKeyVersion: 1
}
```

---

### 📝 Test Case 2: Join nhóm với password SAI

**Request:**
```bash
curl -X POST http://localhost:5000/api/groups/join \
  -H "Authorization: Bearer USER_B_TOKEN" \
  -d '{
    "roomId": "674c5f8a9b...",
    "password": "saimatkhau",
    "encryptedSessionKey": "fake_key"
  }'
```

**Kết quả mong đợi:**
```json
{
  "error": "Incorrect password"
}
HTTP Status: 401 Unauthorized
```

---

### 📝 Test Case 3: Join nhóm với password ĐÚNG

**Request:**
```bash
curl -X POST http://localhost:5000/api/groups/join \
  -H "Authorization: Bearer USER_B_TOKEN" \
  -d '{
    "roomId": "674c5f8a9b...",
    "password": "matkhau123",
    "encryptedSessionKey": "real_encrypted_key_for_user_b"
  }'
```

**Kết quả mong đợi:**
```json
{
  "message": "Joined group successfully",
  "room": {
    "encryptedSessionKey": "real_encrypted_key_for_user_b"
  }
}
```

**Kiểm tra database:**
```bash
db.roommembers.find({ roomId: ObjectId("674c5f8a9b...") })

# Expected: 2 members (admin + user_b)
[
  { userId: "admin_id", encryptedSessionKey: "key_admin", role: "owner" },
  { userId: "user_b_id", encryptedSessionKey: "key_user_b", role: "member" }
]
```

---

### 📝 Test Case 4: Kick member (Key Rotation)

**Bước 1: Admin kick User C**
```bash
curl -X POST http://localhost:5000/api/groups/ROOM_ID/kick \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -d '{
    "memberIdToKick": "user_c_id",
    "newEncryptedSessionKeys": [
      { "userId": "admin_id", "encryptedKey": "new_key_v2_admin" },
      { "userId": "user_b_id", "encryptedKey": "new_key_v2_user_b" }
    ]
  }'
```

**Kết quả mong đợi:**
```json
{
  "message": "Member kicked successfully and session key rotated",
  "room": {
    "sessionKeyVersion": 2  // ✅ Tăng từ 1 lên 2
  }
}
```

**Kiểm tra database:**
```bash
# Room
db.rooms.findOne({ _id: ObjectId("...") })
# Expected:
{
  sessionKeyVersion: 2,  // ✅ Đã tăng
  members: ["admin_id", "user_b_id"]  // ✅ User C đã bị xóa
}

# RoomMember của User C
db.roommembers.findOne({ userId: "user_c_id" })
# Expected:
{
  isActive: false,  // ✅ Đã bị deactivate
  leftAt: Date
}

# RoomMember của User B (còn lại)
db.roommembers.findOne({ userId: "user_b_id" })
# Expected:
{
  encryptedSessionKey: "new_key_v2_user_b",  // ✅ Key mới
  sessionKeyVersion: 2  // ✅ Version mới
}
```

---

## 3. TEST E2EE SECURITY

### 📝 Test Case 1: Server không đọc được tin nhắn

**Bước 1: Gửi tin nhắn**
1. User A gửi: "Secret message 12345"
2. Mở MongoDB

**Kiểm tra database:**
```bash
db.messages.findOne({ sender: "user_a_id" })

# Expected:
{
  content: "x8KmL3pNq9rT5vY...",  // ✅ Mã hóa, KHÔNG phải plaintext
  messageType: "text"
}
```

**Kết quả mong đợi:**
- ✅ Không thấy chữ "Secret message 12345" trong database
- ✅ Chỉ thấy chuỗi base64 encrypted

---

### 📝 Test Case 2: Forward không copy gói tin cũ

**Bước 1: User A gửi cho User B**
```bash
# Xem message trong DB
db.messages.findOne({ sender: "user_a_id", receiver: "user_b_id" })
# Output:
{
  content: "abc123xyz..."  // Encrypted với key A-B
}
```

**Bước 2: User B forward cho User C**
```bash
# Xem message trong DB
db.messages.findOne({ sender: "user_b_id", receiver: "user_c_id", isForwarded: true })
# Output:
{
  content: "def456uvw...",  // ✅ KHÁC với "abc123xyz..." (mã hóa lại)
  isForwarded: true,
  originalSenderId: "user_a_id"
}
```

**Kết quả mong đợi:**
- ✅ `content` của 2 tin KHÁC NHAU
- ✅ Mã hóa lại với key B-C (không copy gói tin A-B)
- ✅ Server không thể liên kết 2 tin nhắn

---

### 📝 Test Case 3: File Key Wrapping (Security)

**Kiểm tra:**
```bash
# Message 1: User A gửi file cho User B
db.messages.findOne({ sender: "user_a_id", receiver: "user_b_id", messageType: "image" })
# Output:
{
  fileUrl: "https://storage.com/abc123.jpg",  // File URL giống nhau
  encryptedFileKey: "x8KmL3..."  // Key mã hóa với public key của B
}

# Message 2: User B forward file cho User C
db.messages.findOne({ sender: "user_b_id", receiver: "user_c_id", isForwarded: true })
# Output:
{
  fileUrl: "https://storage.com/abc123.jpg",  // ✅ CÙNG file URL
  encryptedFileKey: "p9NqW7..."  // ✅ KHÁC key (mã hóa lại cho C)
}
```

**Kết quả mong đợi:**
- ✅ `fileUrl` giống nhau (không upload lại)
- ✅ `encryptedFileKey` khác nhau (re-wrap cho từng user)
- ✅ User B không thể dùng key của mình để mở file của User C

---

## 4. TEST FILE UPLOAD

### 📝 Test Case: Upload và forward file lớn

**Bước 1: Upload file 10MB**
1. User A chọn file 10MB
2. Gửi cho User B
3. Đo thời gian upload

**Bước 2: Forward file**
1. User B forward file cho User C
2. Đo thời gian forward

**So sánh performance:**
```
Upload ban đầu: 10MB → ~5-10 giây (tùy mạng)
Forward:        ~500 bytes → ~0.1 giây ✅

Bandwidth saved: 99.995%!
```

---

## 🐛 TROUBLESHOOTING

### Lỗi: "Failed to decrypt message"
**Nguyên nhân:** Shared key không đúng hoặc bị corrupt

**Cách fix:**
```dart
// Xóa cache encryption keys
await DatabaseHelper.instance.database.delete('encryption_keys');

// Đăng xuất và đăng nhập lại
```

### Lỗi: Tin nhắn bị gửi 2 lần
**Nguyên nhân:** ĐÃ SỬA! Do TextField `onSubmitted` và Button `onPressed` trigger cùng lúc

**Cách fix:** Đã thêm flag `_isSending` để prevent duplicate

### Lỗi: "Group not found"
**Nguyên nhân:** RoomId không đúng hoặc user chưa join

**Cách fix:**
```bash
# Kiểm tra room tồn tại
db.rooms.findOne({ _id: ObjectId("YOUR_ROOM_ID") })

# Kiểm tra user là member
db.roommembers.findOne({ roomId: ObjectId("..."), userId: "..." })
```

---

## 📊 CHECKLIST KIỂM TRA

### Forward Message
- [ ] Forward tin text thành công
- [ ] Forward cho nhiều người cùng lúc
- [ ] Forward hình ảnh (file key wrapping)
- [ ] Forward chain giữ originalSender
- [ ] Badge "Forwarded from" hiển thị đúng
- [ ] Tin nhắn được mã hóa lại (không copy gói tin cũ)

### Group Chat (Backend)
- [ ] Tạo nhóm có password
- [ ] Join nhóm với password đúng
- [ ] Join nhóm với password sai → 401
- [ ] Kick member → sessionKeyVersion tăng
- [ ] Remaining members nhận key mới
- [ ] Kicked member isActive = false

### Security
- [ ] Server không thấy plaintext trong database
- [ ] Mỗi user nhận encrypted content khác nhau
- [ ] File key wrapping hoạt động
- [ ] Key rotation sau khi kick member

### Performance
- [ ] Forward text < 100ms per recipient
- [ ] Forward file không re-upload (99.99% bandwidth saved)
- [ ] Group message broadcast < 50ms

---

**Tạo:** Tháng 12/2025  
**Status:** ✅ Forward Message hoàn thành | 🚧 Group Chat UI đang phát triển
