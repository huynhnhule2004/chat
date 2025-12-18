# Settings & Storage Management - Complete Guide

## 📋 Tổng quan

Hệ thống Settings với Storage Management và Dark Mode cho E2EE Chat App:
- ✅ **Dark Mode** với ThemeProvider và SharedPreferences
- ✅ **Storage Analysis Engine** với Isolate (chạy ngầm)
- ✅ **Storage Management** 3 levels: Clear Cache, Delete Chat, Delete Old Messages
- ✅ **Backend API** cho storage quota tracking
- ✅ **Beautiful UI** giống Telegram/WhatsApp

---

## 🎨 1. Dark Mode Implementation

### ThemeProvider (lib/providers/theme_provider.dart)

**Features:**
- Quản lý theme state với ChangeNotifier
- Lưu preference vào SharedPreferences
- Tự động load theme khi khởi động app
- Toggle giữa Light và Dark mode

**ThemeData Configuration:**

**Light Theme:**
```dart
- Primary Color: Blue
- Background: White
- Card: White với elevation 2
- Text: Black87 / Black54
```

**Dark Theme:**
```dart
- Background: #121212 (Material Dark)
- Card: #1E1E1E
- AppBar: #1E1E1E
- Text: White / White70
- Reduced brightness cho mắt
```

**Usage trong Settings:**
```dart
Consumer<ThemeProvider>(
  builder: (context, themeProvider, _) {
    return SwitchListTile(
      title: Text('Dark Mode'),
      value: themeProvider.isDarkMode,
      onChanged: (value) => themeProvider.setDarkMode(value),
    );
  },
)
```

---

## 📊 2. Storage Analysis Engine

### Kiến trúc

```
StorageService
  ├── analyzeStorage() - Main function (runs on Isolate)
  │   ├── Device Storage Info (total, free, used)
  │   ├── App Storage Calculation
  │   └── Per-Chat Analysis
  │       ├── Message count
  │       ├── Database size
  │       ├── Media files size
  │       └── Cache size
  │
  ├── clearCache() - Level 1 cleanup
  ├── deleteChatHistory(userId) - Level 2 cleanup
  └── deleteOldMessages(duration) - Level 3 cleanup
```

### Storage Models (lib/models/storage_info.dart)

**StorageInfo:**
```dart
- totalBytes: Device total storage
- freeBytes: Device free storage
- usedByApp: App total usage
- chatStorages: Map<userId, ChatStorageInfo>
- Formatted sizes (GB/MB/KB)
- Percentage calculations
```

**ChatStorageInfo:**
```dart
- userId, username
- messageCount
- databaseSize: SQLite portion
- mediaSize: Images/videos/files
- cacheSize: Thumbnails/temp
- files: List<FileStorageInfo>
```

### Isolate Implementation

**Tại sao cần Isolate?**
- Tính toán dung lượng hàng ngàn files rất nặng
- Block main thread → UI freeze
- Isolate chạy ngầm → UI mượt mà

**Implementation:**
```dart
Future<StorageInfo> analyzeStorage() async {
  final params = StorageAnalysisParams(
    appDir: appDir.path,
    dbPath: dbPath,
  );

  // Chạy trên isolate riêng
  final result = await compute(_analyzeAppStorageIsolate, params);
  
  return StorageInfo(...);
}

// Worker function - chạy trên isolate
static Future<Map<String, dynamic>> _analyzeAppStorageIsolate(
  StorageAnalysisParams params,
) async {
  // Heavy computation here
  // - Open database
  // - Count messages
  // - Calculate file sizes
  // - Aggregate results
}
```

**Performance:**
- Main thread: Không bị block
- UI: Vẫn responsive
- Time: 3-5s cho 1000+ files
- Memory: Isolate độc lập

---

## 🧹 3. Storage Management - 3 Levels

### Level 1: Clear Cache (Xóa Cache)

**Target:**
- `/cache/*` - Temporary files
- `/thumbnails/*` - Image previews
- Generated previews

**Preservation:**
- ✅ Original messages (text)
- ✅ Original media files
- ✅ Database records

**Code:**
```dart
Future<int> clearCache() async {
  int deletedSize = 0;
  
  final cacheDir = Directory('${appDir.path}/cache');
  final thumbnailsDir = Directory('${appDir.path}/thumbnails');

  if (await cacheDir.exists()) {
    deletedSize += await _deleteDirectory(cacheDir);
  }
  if (await thumbnailsDir.exists()) {
    deletedSize += await _deleteDirectory(thumbnailsDir);
  }

  // Recreate directories
  await cacheDir.create(recursive: true);
  await thumbnailsDir.create(recursive: true);

  return deletedSize;
}
```

**UI Flow:**
1. User tap "Clear Cache"
2. Confirmation dialog
3. Show loading
4. Delete files
5. Show "Cleared 150MB" snackbar
6. Refresh storage analysis

---

### Level 2: Delete Chat History (Xóa theo Chat)

**Target:**
- All messages in specific conversation
- All media files from that chat
- Database records

**Implementation:**
```dart
Future<int> deleteChatHistory(String userId) async {
  final db = await DatabaseHelper.instance.database;
  
  // 1. Get files list
  final messages = await db.query(
    'messages',
    where: 'receiver_id = ? OR sender_id = ?',
    whereArgs: [userId, userId],
  );

  // 2. Delete files
  for (final msg in messages) {
    final filePath = msg['file_path'];
    if (filePath != null) {
      final file = File('${appDir.path}/$filePath');
      if (await file.exists()) {
        deletedSize += await file.length();
        await file.delete();
      }
    }
  }

  // 3. Delete DB records
  await db.delete('messages', where: 'receiver_id = ? OR sender_id = ?', whereArgs: [userId, userId]);
  await db.delete('conversations', where: 'user_id = ?', whereArgs: [userId]);

  return deletedSize;
}
```

**UI:**
- List all chats với storage size
- Tap chat → "Delete" button
- Confirmation dialog
- Progress indicator
- Success message

---

### Level 3: Delete Old Messages (Xóa theo thời gian)

**Options:**
- 3 months old
- 6 months old
- 1 year old

**Logic:**
```dart
Future<int> deleteOldMessages(Duration age) async {
  final cutoffTime = DateTime.now().subtract(age).millisecondsSinceEpoch;

  final messages = await db.query(
    'messages',
    where: 'timestamp < ?',
    whereArgs: [cutoffTime],
  );

  // Delete files
  for (final msg in messages) {
    // Delete file if exists
  }

  // Delete records
  await db.delete('messages', where: 'timestamp < ?', whereArgs: [cutoffTime]);

  return deletedSize;
}
```

**UI Dialog:**
```dart
showDialog(
  builder: (context) => AlertDialog(
    title: Text('Delete Old Messages'),
    content: Column(
      children: [
        ListTile(title: Text('3 months'), onTap: () => delete(90.days)),
        ListTile(title: Text('6 months'), onTap: () => delete(180.days)),
        ListTile(title: Text('1 year'), onTap: () => delete(365.days)),
      ],
    ),
  ),
)
```

---

## 📱 4. Storage Analysis Screen

### Layout Structure

```
StorageAnalysisScreen
  ├── AppBar (with refresh button)
  ├── Loading State (với progress message)
  └── Content (RefreshIndicator)
      ├── Device Storage Card
      │   ├── Title + Icon
      │   ├── LinearProgressIndicator (storage bar)
      │   └── Used / Free / Total info
      │
      ├── App Storage Card
      │   ├── Total app usage
      │   └── Percentage of device
      │
      ├── Cleanup Section Card
      │   ├── Clear Cache (Level 1)
      │   └── Delete Old Messages (Level 3)
      │
      └── Chat Storage List Card
          └── Per-chat items
              ├── Avatar
              ├── Username
              ├── Message count
              ├── Media size
              ├── Cache size
              └── Delete button
```

### Device Storage Card

**Components:**
- **Progress Bar:** LinearProgressIndicator
  - Green: < 70% used
  - Orange: 70-85% used
  - Red: > 85% used

**Info Display:**
```
Used: 45.2 GB (68.5%)
Free: 20.8 GB (31.5%)
Total: 66.0 GB (100%)
```

### Chat Storage List

**Item Layout:**
```
[Avatar] Username
         150 messages
         📷 120MB  💾 15MB
                        [150MB] [Delete]
```

**Sorting:** Largest to smallest
**Actions:** Tap "Delete" → Confirmation → Remove

---

## 🖥️ 5. Backend API

### GET /api/storage-quota

**Purpose:** Lấy thông tin files user đang lưu trên server

**Response:**
```json
{
  "userStorage": {
    "totalSize": 52428800,
    "totalFiles": 15,
    "formattedSize": "50.00 MB",
    "files": [
      {
        "messageId": "msg_id",
        "fileName": "image.jpg",
        "fileType": "image",
        "size": 2097152,
        "uploadedAt": "2024-01-15T10:00:00.000Z"
      }
    ]
  },
  "serverStorage": {
    "totalSize": 1073741824,
    "formattedSize": "1.00 GB"
  },
  "quota": {
    "limit": 104857600,
    "used": 52428800,
    "remaining": 52428800,
    "percentage": 50.0
  }
}
```

**Implementation:**
```javascript
router.get('/storage-quota', authMiddleware, async (req, res) => {
  // 1. Find user's messages with files
  const messages = await Message.find({
    $or: [{ sender: userId }, { receiver: userId }],
    fileUrl: { $exists: true }
  });

  // 2. Calculate file sizes
  let totalSize = 0;
  for (const message of messages) {
    const stats = await fs.stat(filePath);
    totalSize += stats.size;
  }

  // 3. Return quota info
  res.json({ userStorage, serverStorage, quota });
});
```

---

### DELETE /api/storage/cleanup

**Purpose:** Xóa files cũ trên server

**Request Body:**
```json
{
  "olderThanDays": 90
}
```

**Response:**
```json
{
  "success": true,
  "deletedCount": 25,
  "deletedSize": 52428800,
  "formattedSize": "50.00 MB"
}
```

**Logic:**
1. Find messages older than X days
2. Delete physical files
3. Update message records (remove fileUrl)
4. Return statistics

---

## 🎯 6. Settings Screen

### Layout

**Sections:**
1. **Appearance**
   - Dark Mode toggle

2. **Storage & Data**
   - Storage Overview (quick info)
   - Storage Usage (→ Analysis screen)

3. **Account**
   - Profile
   - Admin Dashboard (if admin)

4. **About**
   - App version
   - About dialog

5. **Logout**
   - Red button with confirmation

### UI Design

**Setting Tile Style:**
```dart
ListTile(
  leading: Container(
    padding: 8px,
    decoration: BoxDecoration(
      color: Primary.withOpacity(0.1),
      borderRadius: 8px,
    ),
    child: Icon(icon, color: Primary),
  ),
  title: Text(title),
  subtitle: Text(subtitle),
  trailing: Icon(chevron_right),
)
```

**Section Header:**
```
APPEARANCE          <- Small, uppercase, colored
Dark Mode           <- Setting tile
```

---

## 🔧 7. Implementation Steps

### Step 1: Install Dependencies

```yaml
# pubspec.yaml
dependencies:
  shared_preferences: ^2.2.2  # Theme persistence
  path_provider: ^2.1.2       # File paths
  sqflite: ^2.3.2             # Database
  provider: ^6.1.1            # State management
```

```bash
flutter pub get
```

---

### Step 2: Integrate ThemeProvider

**Update main.dart:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ChatProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: Consumer<ThemeProvider>(
    builder: (context, themeProvider, _) {
      return MaterialApp(
        theme: themeProvider.lightTheme,
        darkTheme: themeProvider.darkTheme,
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      );
    },
  ),
)
```

---

### Step 3: Add Settings Route

**Update ConversationsScreen:**
```dart
AppBar(
  actions: [
    IconButton(
      icon: Icon(Icons.settings),
      onPressed: () => Navigator.pushNamed(context, '/settings'),
    ),
  ],
)
```

**Add route in main.dart:**
```dart
routes: {
  '/settings': (context) => SettingsScreen(),
}
```

---

### Step 4: Test Storage Analysis

**Flow:**
1. Open Settings
2. Tap "Storage Usage"
3. Wait for analysis (3-5s)
4. View device + app storage
5. View per-chat breakdown
6. Try cleanup actions

---

### Step 5: Test Dark Mode

**Flow:**
1. Open Settings
2. Toggle Dark Mode switch
3. See immediate theme change
4. Close app
5. Reopen → Theme persisted ✅

---

## 📊 8. Performance Optimization

### Isolate Benefits

**Without Isolate:**
```
Main Thread: [UI] [Storage Analysis - 5s] [UI blocked]
User Experience: 😡 Frozen screen
```

**With Isolate:**
```
Main Thread: [UI] [UI] [UI] [UI responsive]
Isolate:     [Storage Analysis - 5s]
User Experience: 😊 Smooth scrolling
```

### Caching Strategy

**First Analysis:** 3-5 seconds
**Cached Result:** Instant display
**Refresh:** Manual or on cleanup

**Implementation:**
```dart
class StorageService {
  StorageInfo? _cachedInfo;
  DateTime? _lastAnalysis;

  Future<StorageInfo> analyzeStorage({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _cachedInfo != null && 
        DateTime.now().difference(_lastAnalysis!) < Duration(minutes: 5)) {
      return _cachedInfo!;
    }

    // Perform analysis
    _cachedInfo = await compute(...);
    _lastAnalysis = DateTime.now();
    return _cachedInfo!;
  }
}
```

---

## 🎨 9. UI/UX Best Practices

### Loading States

**Always show:**
- Progress indicator
- Descriptive message
- Time estimate (if long)

```dart
Center(
  child: Column(
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 16),
      Text('Analyzing storage...'),
      Text('This may take a while', style: TextStyle(fontSize: 12)),
    ],
  ),
)
```

### Confirmation Dialogs

**Critical actions need confirmation:**
- Delete chat history
- Delete old messages
- Clear all data

**Dialog Pattern:**
```dart
showDialog(
  builder: (context) => AlertDialog(
    title: Text('Delete Chat?'),
    content: Text('This will delete all messages and free up 150MB.'),
    actions: [
      TextButton(child: Text('Cancel'), onPressed: () => pop(false)),
      TextButton(child: Text('Delete'), onPressed: () => pop(true)),
    ],
  ),
)
```

### Success Feedback

**After cleanup:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Cleared 150 MB of cache'),
    duration: Duration(seconds: 3),
  ),
);
```

---

## 🔒 10. Security Considerations

### E2EE Maintained

**Storage analysis KHÔNG:**
- ❌ Decrypt messages
- ❌ Read message content
- ❌ Access encryption keys

**Chỉ tính:**
- ✅ File sizes
- ✅ Message count
- ✅ Metadata (timestamp, type)

### Privacy

**Server storage quota:**
- Server chỉ biết: File sizes, upload times
- Server KHÔNG biết: Nội dung files (encrypted)
- Admin KHÔNG thể: Xem/download user files

---

## 📈 11. Testing Checklist

### Dark Mode
- [ ] Toggle works immediately
- [ ] Theme persists after restart
- [ ] All screens respect theme
- [ ] Text readable in both modes
- [ ] Colors adjust properly

### Storage Analysis
- [ ] Device storage shows correct values
- [ ] App usage calculated accurately
- [ ] Per-chat breakdown correct
- [ ] Progress bar updates
- [ ] Refresh button works

### Storage Cleanup
- [ ] Clear cache removes temp files
- [ ] Delete chat removes all data
- [ ] Old messages deletion works
- [ ] Confirmation dialogs appear
- [ ] Success messages show
- [ ] Storage recalculates

### Backend API
- [ ] /api/storage-quota returns data
- [ ] File sizes accurate
- [ ] Quota calculation correct
- [ ] Cleanup endpoint works

---

## 🚀 12. Usage Examples

### Get Storage Info
```dart
final storageService = StorageService();
final info = await storageService.analyzeStorage();

print('App using: ${info.appSize}');
print('Device: ${info.usedPercentage}% full');
```

### Clear Cache
```dart
final deletedSize = await storageService.clearCache();
print('Freed: ${StorageInfo._formatBytes(deletedSize)}');
```

### Delete Chat
```dart
await storageService.deleteChatHistory('user_id_123');
// Chat history cleared
```

### Toggle Dark Mode
```dart
final themeProvider = context.read<ThemeProvider>();
await themeProvider.toggleTheme();
// Theme switches immediately
```

---

## ✅ Summary

**Implemented:**
✅ Dark Mode với SharedPreferences persistence
✅ Storage Analysis Engine với Isolate
✅ 3-level Storage Cleanup (Cache, Chat, Old Messages)
✅ Beautiful Settings UI
✅ Backend Storage Quota API
✅ Per-chat storage breakdown
✅ Performance optimized với caching
✅ E2EE security maintained

**Ready to use!** 🎉
