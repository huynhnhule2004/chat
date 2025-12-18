# Authentication & User Management - Complete Guide

## 📋 Tổng quan

Hệ thống Authentication & User Management đầy đủ với:
- ✅ **Email validation** với regex pattern
- ✅ **Avatar upload** với Multer (giới hạn 2MB)
- ✅ **Profile management** (update email, avatar)
- ✅ **Admin dashboard** với pagination
- ✅ **Ban/Unban users** (admin only)
- ✅ **Role-based access** (user/admin)
- ✅ **E2EE security maintained** (admin không truy cập messages)

---

## 🗄️ Database Schema

### User Model (MongoDB)

```javascript
{
  username: String (required, unique, 3-50 chars),
  email: String (required, unique, validated with regex),
  password: String (hashed with bcrypt),
  publicKey: String (for E2EE key exchange),
  avatar: String (URL path to uploaded image),
  role: String (enum: ['user', 'admin'], default: 'user'),
  isActive: Boolean (default: true),
  isBanned: Boolean (default: false),
  lastActive: Date,
  createdAt: Date,
  updatedAt: Date
}
```

**Email Validation Pattern:** `/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/`

**Key Methods:**
- `toPublicJSON()`: Trả về user object không bao gồm password
- Pre-save hook: Hash password nếu được modify

---

## 🔌 Backend API Endpoints

### 1. Authentication Routes (`/api/auth`)

#### POST `/api/auth/register`
**Mô tả:** Đăng ký tài khoản mới

**Request Body:**
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "securePassword123",
  "publicKey": "base64EncodedPublicKey"
}
```

**Response (201):**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "email": "john@example.com",
    "avatar": null,
    "role": "user",
    "isActive": true,
    "isBanned": false,
    "publicKey": "base64EncodedPublicKey"
  }
}
```

**Errors:**
- 400: Missing fields hoặc validation failed
- 409: Username/email đã tồn tại

---

#### POST `/api/auth/login`
**Mô tả:** Đăng nhập

**Request Body:**
```json
{
  "username": "john_doe",
  "password": "securePassword123"
}
```

**Response (200):**
```json
{
  "token": "jwt_token_here",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "email": "john@example.com",
    "avatar": "/uploads/avatars/1234567890.jpg",
    "role": "user",
    "isActive": true,
    "isBanned": false
  }
}
```

**Errors:**
- 401: Invalid credentials
- 403: Account is banned

---

### 2. Profile Routes (`/api/profile`)
**Authentication Required:** Bearer token in Authorization header

#### GET `/api/profile/me`
**Mô tả:** Lấy thông tin profile hiện tại

**Response (200):**
```json
{
  "id": "user_id",
  "username": "john_doe",
  "email": "john@example.com",
  "avatar": "/uploads/avatars/1234567890.jpg",
  "role": "user",
  "createdAt": "2024-01-15T10:00:00.000Z"
}
```

---

#### POST `/api/profile/upload-avatar`
**Mô tả:** Upload avatar (ảnh đại diện)

**Request:** `multipart/form-data`
```
avatar: [File] (image file)
```

**File Validation:**
- **Allowed types:** JPEG, JPG, PNG, GIF, WebP
- **Max size:** 2MB
- **Storage:** `/uploads/avatars/`
- **Auto delete:** Old avatar tự động xóa khi upload mới

**Response (200):**
```json
{
  "message": "Avatar uploaded successfully",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "avatar": "/uploads/avatars/1234567890-avatar.jpg"
  }
}
```

**Errors:**
- 400: No file uploaded hoặc invalid file type
- 413: File quá lớn (>2MB)

**Implementation với Multer:**
```javascript
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/avatars/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + '-' + file.originalname);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 2 * 1024 * 1024 }, // 2MB
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});
```

---

#### PUT `/api/profile/update`
**Mô tả:** Cập nhật email

**Request Body:**
```json
{
  "email": "newemail@example.com"
}
```

**Response (200):**
```json
{
  "message": "Profile updated successfully",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "email": "newemail@example.com"
  }
}
```

**Errors:**
- 400: Email validation failed
- 409: Email đã được sử dụng

---

#### DELETE `/api/profile/delete-avatar`
**Mô tả:** Xóa avatar hiện tại

**Response (200):**
```json
{
  "message": "Avatar deleted successfully",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "avatar": null
  }
}
```

---

### 3. Admin Routes (`/api/admin`)
**Authentication Required:** Bearer token + role='admin'

**Middleware Protection:**
```javascript
const adminMiddleware = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Admin access required' });
  }
  next();
};
```

---

#### GET `/api/admin/users`
**Mô tả:** Lấy danh sách users với pagination

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20)
- `search`: Search by username or email
- `role`: Filter by role ('user' hoặc 'admin')
- `status`: Filter by status ('active', 'banned', 'all')

**Example Request:**
```
GET /api/admin/users?page=1&limit=20&search=john&role=user&status=active
```

**Response (200):**
```json
{
  "users": [
    {
      "id": "user_id",
      "username": "john_doe",
      "email": "john@example.com",
      "avatar": "/uploads/avatars/123.jpg",
      "role": "user",
      "isActive": true,
      "isBanned": false,
      "lastActive": "2024-01-15T10:00:00.000Z",
      "createdAt": "2024-01-01T00:00:00.000Z"
    }
  ],
  "pagination": {
    "total": 50,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

---

#### POST `/api/admin/ban-user`
**Mô tả:** Ban/Unban user

**Request Body:**
```json
{
  "userId": "user_id_to_ban",
  "isBanned": true
}
```

**Response (200):**
```json
{
  "message": "User banned successfully",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "isBanned": true
  }
}
```

**Security:**
- User bị ban không thể login
- Socket connection tự động reject nếu user bị ban
- Admin không thể ban chính mình

---

#### POST `/api/admin/update-role`
**Mô tả:** Thay đổi role của user

**Request Body:**
```json
{
  "userId": "user_id",
  "role": "admin"
}
```

**Response (200):**
```json
{
  "message": "User role updated successfully",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "role": "admin"
  }
}
```

---

#### GET `/api/admin/stats`
**Mô tả:** Lấy thống kê dashboard

**Response (200):**
```json
{
  "totalUsers": 100,
  "activeUsers": 85,
  "bannedUsers": 5,
  "newUsersToday": 3,
  "newUsersThisWeek": 12,
  "newUsersThisMonth": 45
}
```

---

#### DELETE `/api/admin/users/:userId`
**Mô tả:** Xóa user (cẩn thận!)

**Response (200):**
```json
{
  "message": "User deleted successfully"
}
```

**Warning:** Xóa user sẽ xóa vĩnh viễn tài khoản. Thường nên dùng ban thay vì delete.

---

## 🎨 Flutter UI Implementation

### 1. User Model

```dart
class User {
  final String id;
  final String username;
  final String? email;
  final String? avatar;
  final String? publicKey;
  final String role;
  final bool isActive;
  final bool isBanned;
  final DateTime? lastActive;

  bool get isAdmin => role == 'admin';
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      avatar: json['avatar'],
      publicKey: json['publicKey'],
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      isBanned: json['isBanned'] ?? false,
      lastActive: json['lastActive'] != null 
        ? DateTime.parse(json['lastActive']) 
        : null,
    );
  }
}
```

---

### 2. UserAvatar Widget

**File:** `lib/widgets/user_avatar.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class UserAvatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final double radius;
  final bool showOnlineIndicator;

  const UserAvatar({
    Key? key,
    required this.username,
    this.avatarUrl,
    this.radius = 20,
    this.showOnlineIndicator = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: _getColorFromString(username),
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: ApiService().getAvatarUrl(avatarUrl!),
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => 
                      CircularProgressIndicator(strokeWidth: 2),
                    errorWidget: (context, url, error) => 
                      _buildPlaceholder(),
                  ),
                )
              : _buildPlaceholder(),
        ),
        if (showOnlineIndicator)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.4,
              height: radius * 0.4,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Text(
      username[0].toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.8,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Color _getColorFromString(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final colors = [
      Colors.blue, Colors.green, Colors.orange, 
      Colors.purple, Colors.red, Colors.teal,
    ];
    return colors[hash.abs() % colors.length];
  }
}
```

**Usage:**
```dart
UserAvatar(
  username: user.username,
  avatarUrl: user.avatar,
  radius: 24,
  showOnlineIndicator: true,
)
```

---

### 3. Profile Screen

**File:** `lib/screens/profile_screen.dart`

**Features:**
- View current profile info
- Upload/change avatar với ImagePicker
- Update email với validation
- Delete avatar
- Loading states và error handling

**Key Components:**
```dart
class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        await context.read<ChatProvider>().uploadAvatar(image.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await context.read<ChatProvider>()
        .updateProfile(_emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update email: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

**Navigation:**
```dart
Navigator.of(context).pushNamed('/profile');
```

---

### 4. Admin Dashboard Screen

**File:** `lib/screens/admin_dashboard_screen.dart`

**Features:**
- **Stats Dashboard:** Total users, active, banned, new users
- **User List:** Với avatar, role badge, status
- **Search:** Tìm theo username/email
- **Filters:** Role (all/user/admin), Status (all/active/banned)
- **Pagination:** Previous/Next với page number
- **Actions:** Ban/Unban users với confirmation dialog
- **Role Management:** Promote/demote users

**Stats Section:**
```dart
Widget _buildStatsSection() {
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    children: [
      _StatCard(
        title: 'Total Users',
        value: _stats['totalUsers'].toString(),
        icon: Icons.people,
        color: Colors.blue,
      ),
      _StatCard(
        title: 'Active Users',
        value: _stats['activeUsers'].toString(),
        icon: Icons.person_check,
        color: Colors.green,
      ),
      // ... more stats
    ],
  );
}
```

**User List with Actions:**
```dart
class _UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBan;
  final VoidCallback onRoleChange;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: UserAvatar(
        username: user['username'],
        avatarUrl: user['avatar'],
      ),
      title: Row(
        children: [
          Text(user['username']),
          if (user['role'] == 'admin')
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('ADMIN', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
      subtitle: Text(user['email'] ?? ''),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            child: Text(user['isBanned'] ? 'Unban' : 'Ban'),
            onTap: onBan,
          ),
          PopupMenuItem(
            child: Text('Change Role'),
            onTap: onRoleChange,
          ),
        ],
      ),
    );
  }
}
```

**Pagination:**
```dart
Widget _buildPagination() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      ElevatedButton.icon(
        onPressed: _currentPage > 1 ? _previousPage : null,
        icon: Icon(Icons.arrow_back),
        label: Text('Previous'),
      ),
      Text('Page $_currentPage of $_totalPages'),
      ElevatedButton.icon(
        onPressed: _currentPage < _totalPages ? _nextPage : null,
        icon: Icon(Icons.arrow_forward),
        label: Text('Next'),
      ),
    ],
  );
}
```

**Navigation (Admin Only):**
```dart
if (currentUser.isAdmin) {
  Navigator.of(context).pushNamed('/admin');
}
```

---

## 🔐 Security Implementation

### 1. Socket.io Ban Check

**File:** `backend/services/socketService.js`

```javascript
this.io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if user is banned
    const user = await User.findById(decoded.userId);
    if (!user) {
      return next(new Error('User not found'));
    }
    
    if (user.isBanned) {
      return next(new Error('Account is banned'));
    }
    
    socket.userId = decoded.userId;
    next();
  } catch (error) {
    next(new Error('Authentication error'));
  }
});
```

**Result:** User bị ban không thể connect socket, không thể chat real-time.

---

### 2. Admin Middleware

```javascript
const adminMiddleware = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ 
      message: 'Admin access required' 
    });
  }
  next();
};

router.get('/users', authMiddleware, adminMiddleware, async (req, res) => {
  // Only accessible by admins
});
```

---

### 3. E2EE Protection

**Important:** Admin có thể:
- ✅ Xem danh sách users
- ✅ Ban/unban accounts
- ✅ Thay đổi roles
- ✅ Xem stats

**Admin KHÔNG THỂ:**
- ❌ Đọc nội dung tin nhắn (E2EE encrypted)
- ❌ Xem private keys của users
- ❌ Decrypt messages (không có keys)

Messages được encrypt client-side với ECDH + AES-256-GCM, server chỉ forward encrypted data.

---

## 📝 Testing Guide

### 1. Test Registration với Email

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "publicKey": "base64_public_key_here"
  }'
```

---

### 2. Test Avatar Upload

```bash
curl -X POST http://localhost:3000/api/profile/upload-avatar \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "avatar=@/path/to/image.jpg"
```

---

### 3. Test Admin Ban User

```bash
curl -X POST http://localhost:3000/api/admin/ban-user \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user_id_to_ban",
    "isBanned": true
  }'
```

---

### 4. Test Pagination

```bash
curl "http://localhost:3000/api/admin/users?page=1&limit=10&search=john&status=active" \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN"
```

---

## 🚀 Deployment Steps

### 1. Update Environment Variables

```env
# .env file
JWT_SECRET=your_secure_secret_key
MONGODB_URI=mongodb://localhost:27017/e2ee_chat
PORT=3000
```

---

### 2. Create Admin Account

**Option 1:** Manually in MongoDB:
```javascript
db.users.updateOne(
  { username: "admin" },
  { $set: { role: "admin" } }
)
```

**Option 2:** Via API (đăng ký bình thường, sau đó update):
```bash
# Register account
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "email": "admin@example.com", "password": "securepassword", "publicKey": "..."}'

# Update to admin in MongoDB
db.users.updateOne({username: "admin"}, {$set: {role: "admin"}})
```

---

### 3. Ensure Uploads Directory Exists

```bash
mkdir -p backend/uploads/avatars
chmod 755 backend/uploads/avatars
```

---

### 4. Start Backend Server

```bash
cd backend
npm install
npm start
```

Server chạy trên `http://localhost:3000`

---

### 5. Run Flutter App

```bash
cd flutter
flutter pub get
flutter run -d windows  # hoặc -d chrome, -d android
```

---

## 📱 User Flow Examples

### New User Registration Flow

1. User mở app → LoginScreen
2. Tap "Register" → Form hiện email field
3. Nhập username, email, password
4. Tap Register button
5. Client generate ECDH key pair
6. POST `/api/auth/register` với email, publicKey
7. Server validate email regex, hash password, save to MongoDB
8. Server return JWT token + user object
9. Client lưu token, navigate to ConversationsScreen

---

### Avatar Upload Flow

1. User tap Profile icon → ProfileScreen
2. Tap avatar → Show ImagePicker (Camera/Gallery)
3. Pick image → Local file path
4. Show loading indicator
5. POST `/api/profile/upload-avatar` với multipart/form-data
6. Server validate file type, size
7. Multer save to `/uploads/avatars/`
8. Server delete old avatar nếu tồn tại
9. Update user.avatar in MongoDB
10. Return updated user object
11. Client update ChatProvider, refresh UI
12. Avatar hiển thị với CachedNetworkImage

---

### Admin Ban User Flow

1. Admin login → ConversationsScreen
2. Admin icon visible → Tap to AdminDashboardScreen
3. View user list với pagination
4. Find user → Tap menu → "Ban"
5. Confirmation dialog → Confirm
6. POST `/api/admin/ban-user` với userId, isBanned=true
7. Server update user.isBanned in MongoDB
8. Return success message
9. UI update user status badge
10. Banned user tries to login → 403 Forbidden
11. Banned user tries socket connect → Rejected

---

## ⚠️ Common Issues & Solutions

### 1. Email Already Exists

**Error:** `409 Conflict - Email already exists`

**Solution:** 
- Check if email already registered
- Use unique email for each account
- Or implement "Forgot Password" flow

---

### 2. Avatar Upload Fails

**Error:** `400 Bad Request - Invalid file type`

**Cause:** File không phải image type

**Solution:**
- Chỉ upload JPEG, PNG, GIF, WebP
- Check file extension trước khi upload
- Validate trên client trước khi gửi

---

### 3. File Too Large

**Error:** `413 Payload Too Large`

**Solution:**
- Compress image trước khi upload
- Giảm quality với ImagePicker
- Resize về max width/height

```dart
final image = await picker.pickImage(
  source: source,
  maxWidth: 512,
  maxHeight: 512,
  imageQuality: 85,
);
```

---

### 4. Admin Can't Access Dashboard

**Error:** `403 Forbidden - Admin access required`

**Cause:** User role không phải 'admin'

**Solution:**
```javascript
// Update user role in MongoDB
db.users.updateOne(
  { username: "your_username" },
  { $set: { role: "admin" } }
)
```

---

### 5. Pagination Empty Results

**Issue:** Total pages calculation wrong

**Fix:**
```javascript
const totalPages = Math.ceil(total / limit) || 1;
```

---

## 🎯 Best Practices

### 1. Avatar Management
- Luôn validate file type và size
- Delete old avatar khi upload new
- Use unique filenames (timestamp + random)
- Store relative paths, not absolute
- Implement image compression

### 2. Email Validation
- Validate trên client và server
- Use consistent regex pattern
- Trim whitespace trước khi validate
- Check for duplicates trong database

### 3. Ban System
- Show clear message khi login fails
- Disconnect banned users từ socket
- Log ban actions để audit
- Allow unban nếu cần restore

### 4. Admin Security
- Never allow admin to view encrypted messages
- Log all admin actions
- Require strong password cho admin accounts
- Implement 2FA cho admin accounts (optional)

### 5. Pagination Performance
- Always use indexes trên username, email
- Limit max page size (e.g., 100)
- Cache stats cho performance
- Use skip/limit efficiently

---

## 📚 API Service Methods (Flutter)

```dart
class ApiService {
  // Profile
  Future<Map<String, dynamic>> uploadAvatar(String filePath);
  Future<Map<String, dynamic>> updateProfile(String email);
  Future<Map<String, dynamic>> deleteAvatar();
  
  // Admin
  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
    String? status,
  });
  Future<Map<String, dynamic>> banUser(String userId, bool isBanned);
  Future<Map<String, dynamic>> updateUserRole(String userId, String role);
  Future<Map<String, dynamic>> getAdminStats();
  Future<void> deleteUser(String userId);
  
  // Utilities
  String getAvatarUrl(String avatarPath);
}
```

---

## ✅ Checklist Hoàn Thành

- [x] User model với email, avatar, role, isBanned
- [x] Email validation với regex
- [x] Avatar upload với Multer (2MB limit)
- [x] Profile update API
- [x] Admin routes với adminMiddleware
- [x] User list với pagination
- [x] Ban/Unban functionality
- [x] Role management (user/admin)
- [x] Admin stats dashboard
- [x] Flutter UserAvatar widget
- [x] Flutter ProfileScreen
- [x] Flutter AdminDashboardScreen
- [x] Navigation routing
- [x] Socket ban check
- [x] E2EE security maintained

---

## 🎉 Kết luận

Hệ thống Authentication & User Management đã hoàn thiện với đầy đủ tính năng:
- Email validation và avatar management
- Admin dashboard với pagination và user control
- Security maintained (admin không truy cập E2EE messages)
- Clean UI với material design và proper loading states
- Error handling và validation ở mọi layer

**Ready for production!** 🚀
