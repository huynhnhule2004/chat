/**
 * @swagger
 * components:
 *   schemas:
 *     WebSocketEvent:
 *       type: object
 *       properties:
 *         event:
 *           type: string
 *           description: Tên event
 *         data:
 *           type: object
 *           description: Dữ liệu của event
 *         timestamp:
 *           type: string
 *           format: date-time
 *           description: Thời gian gửi event
 * 
 * /websocket:
 *   get:
 *     summary: WebSocket Connection
 *     description: |
 *       ## WebSocket API cho Chat Real-time
 *       
 *       **Kết nối**: `ws://localhost:5000`
 *       
 *       **Authentication**: Gửi JWT token trong handshake hoặc sau khi connect:
 *       ```javascript
 *       const socket = io('http://localhost:5000', {
 *         auth: {
 *           token: 'your-jwt-token'
 *         }
 *       });
 *       ```
 *       
 *       ### Client Events (Gửi từ client):
 *       
 *       #### 1. `authenticate`
 *       Xác thực người dùng (nếu chưa auth trong handshake)
 *       ```javascript
 *       socket.emit('authenticate', { token: 'your-jwt-token' });
 *       ```
 *       
 *       #### 2. `join_room`
 *       Tham gia phòng chat (direct chat hoặc group)
 *       ```javascript
 *       socket.emit('join_room', {
 *         roomId: '60f7b3b3b3b3b3b3b3b3b3b6',
 *         type: 'direct' // hoặc 'group'
 *       });
 *       ```
 *       
 *       #### 3. `leave_room`
 *       Rời phòng chat
 *       ```javascript
 *       socket.emit('leave_room', {
 *         roomId: '60f7b3b3b3b3b3b3b3b3b3b6'
 *       });
 *       ```
 *       
 *       #### 4. `new_message`
 *       Gửi tin nhắn mới (đã được mã hóa E2EE)
 *       ```javascript
 *       socket.emit('new_message', {
 *         recipientId: '60f7b3b3b3b3b3b3b3b3b3b5', // cho direct message
 *         roomId: '60f7b3b3b3b3b3b3b3b3b3b6',     // cho group message
 *         encryptedContent: 'U2FsdGVkX1+vupppZksvRf5pq5g5XjFR...',
 *         messageType: 'text',
 *         fileUrl: '/uploads/1234567890-file.jpg' // optional
 *       });
 *       ```
 *       
 *       #### 5. `user_typing`
 *       Thông báo đang gõ tin nhắn
 *       ```javascript
 *       socket.emit('user_typing', {
 *         roomId: '60f7b3b3b3b3b3b3b3b3b3b6',
 *         isTyping: true
 *       });
 *       ```
 *       
 *       #### 6. `mark_as_read`
 *       Đánh dấu tin nhắn đã đọc
 *       ```javascript
 *       socket.emit('mark_as_read', {
 *         messageId: '60f7b3b3b3b3b3b3b3b3b3b4'
 *       });
 *       ```
 *       
 *       ### Server Events (Nhận từ server):
 *       
 *       #### 1. `authenticated`
 *       Xác nhận authentication thành công
 *       ```javascript
 *       socket.on('authenticated', (data) => {
 *         console.log('User authenticated:', data.user);
 *       });
 *       ```
 *       
 *       #### 2. `message_received`
 *       Nhận tin nhắn mới
 *       ```javascript
 *       socket.on('message_received', (message) => {
 *         // message có cấu trúc giống Message schema
 *         console.log('New message:', message);
 *       });
 *       ```
 *       
 *       #### 3. `user_online` / `user_offline`
 *       Thông báo trạng thái online/offline của user
 *       ```javascript
 *       socket.on('user_online', (data) => {
 *         console.log('User came online:', data.userId);
 *       });
 *       
 *       socket.on('user_offline', (data) => {
 *         console.log('User went offline:', data.userId);
 *       });
 *       ```
 *       
 *       #### 4. `user_typing`
 *       Nhận thông báo user đang gõ
 *       ```javascript
 *       socket.on('user_typing', (data) => {
 *         console.log('User typing:', data.userId, data.isTyping);
 *       });
 *       ```
 *       
 *       #### 5. `room_updated`
 *       Thông báo room được cập nhật (thêm/xóa member, đổi tên, etc.)
 *       ```javascript
 *       socket.on('room_updated', (data) => {
 *         console.log('Room updated:', data.room);
 *       });
 *       ```
 *       
 *       #### 6. `error`
 *       Thông báo lỗi
 *       ```javascript
 *       socket.on('error', (error) => {
 *         console.error('Socket error:', error.message);
 *       });
 *       ```
 *       
 *       ### Mã hóa E2EE Flow:
 *       
 *       1. **Direct Messages**:
 *          - Client A lấy public key của Client B qua API `/api/users/{userId}/public-key`
 *          - Client A generate AES key ngẫu nhiên
 *          - Client A mã hóa message bằng AES key
 *          - Client A mã hóa AES key bằng RSA public key của Client B
 *          - Gửi cả encrypted message và encrypted AES key
 *       
 *       2. **Group Messages**:
 *          - Room có session key được mã hóa cho từng member
 *          - Client decrypt session key bằng private key của mình
 *          - Sử dụng session key để encrypt/decrypt group messages
 *       
 *       ### Error Codes:
 *       - `AUTH_REQUIRED`: Cần authentication
 *       - `INVALID_TOKEN`: JWT token không hợp lệ
 *       - `ROOM_NOT_FOUND`: Không tìm thấy room
 *       - `PERMISSION_DENIED`: Không có quyền truy cập
 *       - `INVALID_DATA`: Dữ liệu gửi không hợp lệ
 *       
 *     tags: [WebSocket]
 *     parameters: []
 *     responses:
 *       '101':
 *         description: Switching Protocols - WebSocket connection established
 *       '401':
 *         description: Authentication required
 *       '403':
 *         description: Forbidden
 */
