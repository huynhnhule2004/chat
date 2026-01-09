# TODO để hoàn thiện chat nhóm + chia sẻ file

## Backend (Node)
- [x] Bổ sung API GET `/api/groups/:roomId/messages` (auth + kiểm tra thành viên, phân trang, trả `iv`, `authTag`, `fileUrl`, `encryptedFileKey`, `sessionKeyVersion`) để client tải lịch sử nhóm và đồng bộ khi đổi thiết bị.
- [ ] Thiết lập luồng duyệt thành viên công khai/pending: owner nhận danh sách pending, mã hóa session key cho từng người, cập nhật `RoomMember` và bắn socket `group_key_ready`/`member_approved`.
- [ ] Hoàn thiện key rotation server-side: sau `/kick` gửi socket yêu cầu client tải key mới, ghi `sessionKeyVersion` xuống `RoomMember`, bảo vệ việc dùng key cũ.
- [ ] Gia cố upload/download file: bắt buộc auth cho GET `/uploads/*`, chặn MIME/virus basic, thêm metadata kích thước/loại, dọn file khi xóa room/message, giữ limit 100MB và logging.
- [ ] Cân bằng thuật toán RSA: backend dùng OAEP; thêm flag/metadata để client biết padding, hoặc hỗ trợ PKCS1 tạm thời rồi chuẩn hóa về OAEP.

## Frontend (Flutter)
- [x] `GroupChatScreen`: tính `isMe` từ `_currentUserId`, disable input khi chưa có session key/pending, lưu tin nhắn nhóm vào SQLite khi nhận/gửi, kéo lịch sử từ API mới (có phân trang) khi mở phòng.
- [ ] Tích hợp quản lý nhóm: màn danh sách thành viên + quyền, owner có nút add/kick/delete/transfer; gọi `/api/groups/:roomId/(add-member|kick|delete|leave)` và cập nhật DB local.
- [ ] Luồng rotate key: lấy public keys các member, sinh session key mới bằng `GroupKeyService` (OAEP), cập nhật `sessionKeyVersion`, lưu key mới vào secure storage, gửi socket thông báo để refresh.
- [ ] Gỡ TODO chia sẻ file nhóm: mở file picker, mã hóa file key (dùng session key hoặc rewrap per-member), upload qua `/api/files/upload`, nhúng `fileUrl/encryptedFileKey` vào socket, render bubble file/image/video + nút download/phát (cả chat 1-1: copy/delete/preview/download TODO ở `chat_screen.dart`).
- [ ] Đồng bộ provider: đưa group messages/unread counts vào `ChatProvider`, subscribe `group_typing` và hiển thị typing indicator, refresh `GroupListScreen` khi nhận socket `receive_group_message`.
- [ ] Hoàn thiện xử lý pending join: nếu `pending=true` (JoinGroupDialog), hiển thị trạng thái chờ, chặn gửi, và lắng nghe khi owner cấp encrypted key để lưu session key.
- [ ] Sync RSA public key cho user cũ (TODO trong `utils/key_migration_helper.dart`) để server luôn có public key phục vụ mã hóa session key.

## Bảo mật/Deploy
- [ ] Khóa CORS theo domain thật, thêm rate limit + validation đầu vào (password strength, chiều dài tên group, kiểm tra kích thước mô tả/URL).
- [ ] Cấu hình secrets qua `.env` (JWT_SECRET, MONGODB_URI, upload path), thay mật khẩu Mongo được công khai trong `backend/mongodbinfo.md`, thêm hướng dẫn backup và rotation.
- [ ] Thêm cleanup/monitoring: quota lưu trữ file, cron xóa message cũ theo `MESSAGE_LIMIT`, log audit cho hành động nhóm (kick/rotate/add).

## Kiểm thử & Tài liệu
- [ ] Viết test backend (Jest/Supertest) cho create/join (password & pending), add/kick + key rotation, gửi nhận socket `send_group_message`, tải file upload.
- [ ] Viết test Flutter (widget/integration) cho tạo/join nhóm, gửi/nhận + giải mã tin nhắn, rotate key, attach & tải file, trạng thái pending.
- [ ] Cập nhật docs: hợp nhất trạng thái giữa `GROUP_CHAT_SUMMARY.md` và `GROUP_CHAT_READY.md`, bổ sung guide cho file encryption nhóm, checklist manual QA (latency, reconnect, offline).
