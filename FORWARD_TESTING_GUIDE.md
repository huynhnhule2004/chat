# 🧪 Testing Forward Message Feature

## 📋 Pre-requisites

### 1. Start Backend Server

```bash
cd backend
npm run dev
```

✅ Backend should log: `✓ Server running on port 3000`

### 2. Start Flutter App

```bash
cd flutter
flutter run -d windows
```

✅ App should launch successfully

---

## 🎯 Test Case 1: Forward Text Message (Basic)

### Setup
1. Login với 3 accounts:
   - User A (test_a@test.com / password123)
   - User B (test_b@test.com / password123) 
   - User C (test_c@test.com / password123)

### Steps
1. **User B → User A**: Gửi "Hello World!"
2. **User A**: 
   - Long-press message "Hello World!"
   - Menu hiện ra với options: Forward, Copy, Delete
   - Tap "Forward"
3. **Contact Selection Screen**:
   - Kiểm tra User C hiện trong list
   - Tap checkbox User C (check mark appears)
   - Tap FAB "Forward (1)" hoặc nút Send ở AppBar
4. **Loading Dialog** hiện ra trong vài giây
5. **Success SnackBar**: "Message forwarded to 1 contact(s)"

### Expected Results
✅ User C nhận message "Hello World!"  
✅ Message có badge "↗ Forwarded from User B"  
✅ Content giống hệt original (E2EE decrypt/re-encrypt thành công)

### Verification
```sql
-- Check SQLite database
sqlite3 e2ee_chat.db
SELECT sender_id, receiver_id, content, is_forwarded, forwarded_from 
FROM messages 
WHERE receiver_id = 'user_c_id' 
ORDER BY timestamp DESC LIMIT 1;

-- Should show:
-- sender_id: user_a_id
-- receiver_id: user_c_id
-- is_forwarded: 1
-- forwarded_from: User B
```

---

## 🎯 Test Case 2: Multi-Forward (Stress Test)

### Steps
1. User A long-press message "Hello World!"
2. Chọn Forward
3. **Select 5 contacts**: User C, D, E, F, G
4. Tap "Forward (5)"

### Expected Results
✅ Loading dialog ~2-3 seconds (re-encrypt 5 lần)  
✅ Success: "Message forwarded to 5 contact(s)"  
✅ Mỗi user (C, D, E, F, G) nhận message riêng biệt  
✅ Mỗi message được mã hóa với shared key riêng

### Performance Benchmark
- Re-encryption time: ~20ms × 5 = 100ms
- Total time: < 500ms
- UI responsive (không lag)

---

## 🎯 Test Case 3: Forward Image (File Key Wrapping)

### Setup
1. User B gửi image (5MB) cho User A
   - Backend upload to MinIO/S3 → fileUrl
   - FileKey encrypted với Key_BA → encryptedFileKey

### Steps
1. User A long-press image message
2. Forward → Select User C
3. **Monitor Network Traffic** (DevTools Network tab)

### Expected Results
✅ Network upload: **< 100KB** (chỉ re-wrap file key)  
✅ User C nhận image với badge "Forwarded from User B"  
✅ User C tap image → download và decrypt thành công  
✅ Image hiển thị chính xác

### Verification - File Key Wrapping
```javascript
// Check backend logs
// Should NOT see: "File uploaded: 5MB"
// Should see: "Message sent: user_a_id -> user_c_id (forwarded)"

// Check message data
{
  fileUrl: "https://s3.../image.jpg", // Same URL!
  encryptedFileKey: "AJD9823..." // Different key (re-wrapped)
}
```

### Performance Comparison
| Action | With Re-upload | With Key Wrapping | Savings |
|--------|---------------|-------------------|---------|
| Forward 5MB image to 1 user | 5MB upload | 256 bytes | 99.995% |
| Forward 5MB image to 10 users | 50MB upload | 2.5KB | 99.995% |
| Forward 100MB video to 20 users | 2GB upload | 5KB | 99.9997% |

---

## 🎯 Test Case 4: Chain Forward

### Scenario
User B → User A → User C → User D

### Steps
1. User B sends "Original" to User A
2. User A forwards to User C
3. User C forwards to User D

### Expected Results for User D's Message
✅ Content: "Original"  
✅ Badge: "Forwarded from **User B**" (NOT "User C")  
✅ originalSenderId: User B's ID (preserved through chain)

### Verification
```dart
// In User D's database
Message {
  content: "Original",
  isForwarded: true,
  originalSenderId: "user_b_id", // Original sender!
  forwardedFrom: "User B",
}
```

---

## 🎯 Test Case 5: Forward with Different Message Types

### Test Matrix
| Message Type | Content | Expected Result |
|--------------|---------|-----------------|
| Text | "Hello World!" | ✅ Forward badge + text |
| Image | cat.jpg (2MB) | ✅ Forward badge + image thumbnail |
| Video | demo.mp4 (50MB) | ✅ Forward badge + video player |
| File | document.pdf (5MB) | ✅ Forward badge + file icon |

### Steps for Each Type
1. User B sends [message type] to User A
2. User A forwards to User C
3. Verify badge + content display correctly

---

## 🐛 Common Issues & Troubleshooting

### Issue 1: "No shared key found"
**Symptom:** Error when forwarding  
**Fix:** 
```bash
# Ensure users have exchanged at least 1 message before forwarding
# Shared key is created on first message exchange
```

### Issue 2: "Failed to decrypt message"
**Symptom:** Forward succeeds but content is garbled  
**Debug:**
```dart
// Check crypto_service.dart logs
flutter logs | grep "decrypt"
flutter logs | grep "encrypt"

// Verify shared keys exist
SELECT user_id, shared_key FROM encryption_keys;
```

### Issue 3: Forward badge not showing
**Symptom:** Message received but no "Forwarded from" badge  
**Fix:**
```sql
-- Check database migration ran
PRAGMA table_info(messages);
-- Should show: is_forwarded, original_sender_id, forwarded_from columns

-- If missing, restart app to trigger migration
```

### Issue 4: Image/Video not loading after forward
**Symptom:** Badge shows but file won't open  
**Debug:**
```dart
// Check file URL and encrypted file key
flutter logs | grep "fileUrl"
flutter logs | grep "encryptedFileKey"

// Verify file key wrapping
// encryptedFileKey should be DIFFERENT for each recipient
```

---

## 📊 Performance Testing

### Test: Forward to 20 Users Simultaneously

```dart
// Create 20 test users
for (int i = 1; i <= 20; i++) {
  await createUser('test_user_$i@test.com', 'password123');
}

// Forward 100MB video to all 20
Stopwatch stopwatch = Stopwatch()..start();
await forwardMessage(message, recipients: 20users);
stopwatch.stop();

print('Time: ${stopwatch.elapsedMilliseconds}ms');
print('Network upload: ${uploadedBytes} bytes');
```

**Expected Results:**
- Time: < 2 seconds
- Network upload: < 10KB (20 × 256 bytes file keys)
- Memory: < 50MB increase
- UI responsive throughout

---

## ✅ Final Checklist

### UI/UX
- [ ] Long-press menu appears instantly
- [ ] Contact selection screen loads < 500ms
- [ ] Multi-select checkboxes work smoothly
- [ ] Loading dialog shows during forward
- [ ] Success/error SnackBar appears
- [ ] Forward badge displays correctly
- [ ] Original sender name shows

### Functionality
- [ ] Text message forwards correctly
- [ ] Image forwards without re-upload
- [ ] Video forwards without re-upload
- [ ] Multi-select forwards to all recipients
- [ ] Chain forward preserves original sender
- [ ] Each recipient gets uniquely encrypted message

### Security
- [ ] Messages re-encrypted per recipient
- [ ] File keys re-wrapped (not shared)
- [ ] No plaintext in network traffic
- [ ] Database stores encrypted content only
- [ ] Shared keys never transmitted over socket

### Performance
- [ ] Forward 1 message < 100ms
- [ ] Forward to 10 users < 1 second
- [ ] File key wrapping < 30ms per recipient
- [ ] No UI lag during forward
- [ ] Network bandwidth < 10KB per forward

---

## 🚀 Production Readiness

### Security Audit
```bash
# Check for hardcoded secrets
grep -r "password\|secret\|key" lib/ --exclude-dir=.dart_tool

# Verify no debug prints in production
grep -r "print(" lib/ | grep -v "// TODO"

# Check API key rotation
# backend/.env should use env variables, not hardcoded
```

### Load Testing
```bash
# Use Apache Bench or k6 to simulate load
k6 run load-test-forward.js

# Expected: 
# - 100 concurrent forwards/sec
# - < 200ms p95 latency
# - 0% error rate
```

### Monitoring
```javascript
// Add to backend/services/socketService.js
console.log(`[FORWARD] ${senderId} → ${recipientIds.join(',')} | fileSize: ${fileSize || 0}`);

// Track metrics:
// - Total forwards per day
// - Average recipients per forward
// - File vs text forward ratio
// - Re-encryption time percentiles
```

---

## 📝 Test Report Template

```markdown
## Forward Message Test Report

**Tester:** [Your Name]
**Date:** 2025-12-18
**Environment:** Windows / MacOS / Linux
**Flutter Version:** 3.x.x
**Backend Version:** Node.js 20.x

### Test Results

| Test Case | Status | Notes |
|-----------|--------|-------|
| TC1: Forward Text | ✅ Pass | |
| TC2: Multi-Forward | ✅ Pass | |
| TC3: Forward Image | ✅ Pass | |
| TC4: Chain Forward | ✅ Pass | |
| TC5: Message Types | ✅ Pass | |

### Performance Metrics

- Average forward time: XXms
- Network usage: XXkb
- Memory usage: XXmb

### Issues Found

1. [Issue description]
2. [Issue description]

### Recommendations

- [Recommendation 1]
- [Recommendation 2]
```

---

## 🎉 Happy Testing!

**Quick Start:**
1. `cd backend && npm run dev`
2. `cd flutter && flutter run -d windows`
3. Login 3 users → Test forward flow
4. Check badges, performance, encryption

**Questions?** See [FORWARD_MESSAGE_GUIDE.md](./FORWARD_MESSAGE_GUIDE.md)
