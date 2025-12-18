# 🚀 Quick Test Commands

## Setup Test Environment

### 1. Create Test Users
```bash
cd backend
node test-forward-helper.js
```

**Output:**
```
✅ Created: test_a (ID: 6765...)
✅ Created: test_b (ID: 6765...)
✅ Created: test_c (ID: 6765...)
✅ Created: test_d (ID: 6765...)
✅ Created: test_e (ID: 6765...)
```

---

## Test Forward Flow (Manual)

### Test 1: Basic Forward
```bash
# Terminal 1: Backend
cd backend
npm run dev

# Terminal 2: Flutter
cd flutter
flutter run -d windows
```

**In Flutter App:**
1. Login as `test_b@test.com`
2. Send "Hello World!" to test_a
3. Login as `test_a@test.com`
4. Long-press message → Forward → Select test_c
5. Login as `test_c@test.com`
6. ✅ Should see "Forwarded from test_b"

---

## Database Checks

### Check Forwarded Messages (MongoDB)
```bash
mongosh "mongodb://localhost:27017/e2ee_chat"

# Show all forwarded messages
db.messages.find({ isForwarded: true }).pretty()

# Check specific forward
db.messages.findOne(
  { receiver: ObjectId("user_c_id"), isForwarded: true },
  { content: 1, forwardedFrom: 1, originalSenderId: 1 }
)

# Count forwards by user
db.messages.aggregate([
  { $match: { isForwarded: true } },
  { $group: { _id: "$forwardedFrom", count: { $sum: 1 } } }
])
```

### Check Forwarded Messages (SQLite)
```bash
cd flutter
sqlite3 data/e2ee_chat.db

# Show forwarded messages
SELECT 
  sender_id, 
  receiver_id, 
  is_forwarded, 
  forwarded_from, 
  substr(content, 1, 50) as content_preview
FROM messages 
WHERE is_forwarded = 1
ORDER BY timestamp DESC
LIMIT 10;

# Check file key wrapping
SELECT 
  id,
  file_url,
  length(encrypted_file_key) as key_length,
  file_size
FROM messages
WHERE encrypted_file_key IS NOT NULL;
```

---

## Performance Testing

### Test Forward Speed
```dart
// Add to chat_screen.dart for testing
final stopwatch = Stopwatch()..start();
await ForwardService.instance.forwardMessage(...);
stopwatch.stop();
print('⚡ Forward time: ${stopwatch.elapsedMilliseconds}ms');
```

### Monitor Network Traffic
```bash
# In Chrome DevTools or Flutter DevTools
# Network tab → Filter by "socket.io"

# Should see SMALL payloads (< 1KB for text)
# Should NOT see large file uploads when forwarding media
```

---

## Automated Tests (Future)

### Unit Tests
```dart
// test/services/forward_service_test.dart
test('Re-encrypt message for recipient', () async {
  final message = Message(
    content: 'encrypted_content_for_A',
    senderId: 'user_b',
    ...
  );
  
  final forwarded = await ForwardService.instance.forwardMessage(
    originalMessage: message,
    recipients: [userC],
    currentUserId: 'user_a',
  );
  
  expect(forwarded.length, 1);
  expect(forwarded[0].isForwarded, true);
  expect(forwarded[0].forwardedFrom, 'User B');
  // Content should be DIFFERENT (re-encrypted)
  expect(forwarded[0].content, isNot(message.content));
});
```

### Integration Tests
```dart
// integration_test/forward_test.dart
testWidgets('Forward message flow', (tester) async {
  // Login as User A
  await tester.pumpWidget(MyApp());
  await loginAs('test_a@test.com');
  
  // Open chat with User B
  await tester.tap(find.text('test_b'));
  await tester.pumpAndSettle();
  
  // Long-press first message
  await tester.longPress(find.byType(MessageBubble).first);
  await tester.pumpAndSettle();
  
  // Tap Forward
  await tester.tap(find.text('Forward'));
  await tester.pumpAndSettle();
  
  // Select User C
  await tester.tap(find.text('test_c'));
  await tester.pumpAndSettle();
  
  // Confirm forward
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
  
  // Verify success message
  expect(find.text('Message forwarded to 1 contact(s)'), findsOneWidget);
});
```

---

## Debug Commands

### Flutter Logs
```bash
# Watch all logs
flutter logs

# Filter forward-related logs
flutter logs | grep -i "forward\|encrypt\|decrypt"

# Check errors
flutter logs | grep -i "error\|exception"
```

### Backend Logs
```bash
# Watch Node.js logs
cd backend
npm run dev | grep -i "forward"

# Check socket events
npm run dev | grep "send_message\|receive_message"
```

### Network Debugging
```bash
# Monitor socket.io traffic (Chrome DevTools)
1. Open DevTools → Network tab
2. Filter: "socket.io"
3. Watch "send_message" payload size
4. For file forwards: should be < 1KB (only file key)
```

---

## Troubleshooting Commands

### Reset Test Environment
```bash
# Clear Flutter database
cd flutter
rm -rf data/

# Clear backend database
mongosh
use e2ee_chat
db.messages.deleteMany({ isForwarded: true })

# Recreate test users
cd backend
node test-forward-helper.js
```

### Check Shared Keys
```bash
# SQLite
sqlite3 flutter/data/e2ee_chat.db
SELECT * FROM encryption_keys;

# MongoDB
mongosh
use e2ee_chat
db.users.find({}, { username: 1, publicKey: 1 })
```

### Verify File URLs
```bash
# Check if files exist on server
cd backend/uploads
ls -lh

# Check file references in DB
mongosh
db.messages.find({ fileUrl: { $exists: true } }, { fileUrl: 1, fileSize: 1 })
```

---

## Quick Test Checklist

```bash
# ✅ Backend running
curl http://localhost:3000/api/health

# ✅ Test users created
node backend/test-forward-helper.js

# ✅ Flutter app running
flutter devices
flutter run -d windows

# ✅ Database accessible
mongosh "mongodb://localhost:27017/e2ee_chat"
sqlite3 flutter/data/e2ee_chat.db

# ✅ Forward feature working
# (Manual test in app)
```

---

## Performance Benchmarks

### Expected Results

| Metric | Expected | Actual |
|--------|----------|--------|
| Text forward (1 user) | < 100ms | ___ ms |
| Text forward (10 users) | < 1s | ___ ms |
| Image forward (no re-upload) | < 200ms | ___ ms |
| Video forward (100MB to 20 users) | < 2s | ___ ms |
| Network per text forward | < 1KB | ___ KB |
| Network per file forward | < 500 bytes | ___ bytes |

### Measure Performance

```dart
// In forward_service.dart
final start = DateTime.now();
final result = await forwardMessage(...);
final duration = DateTime.now().difference(start);
print('⚡ Forward completed in ${duration.inMilliseconds}ms');
```

---

## 🎯 Test Now!

**Quickest test:**
```bash
# 1. Start services
cd backend && npm run dev &
cd flutter && flutter run -d windows &

# 2. Create users
node backend/test-forward-helper.js

# 3. Test in app
# - Login as test_b → send message to test_a
# - Login as test_a → long-press → forward to test_c
# - Login as test_c → verify "Forwarded from test_b"

# 4. Check database
mongosh -eval 'use e2ee_chat; db.messages.find({ isForwarded: true }).count()'
```

**Expected output:** `✅ 1 forwarded message found`

---

📖 **Full guide:** [FORWARD_TESTING_GUIDE.md](./FORWARD_TESTING_GUIDE.md)
