/**
 * @swagger
 * tags:
 *   name: Socket.io Events
 *   description: Real-time communication events via Socket.io
 */

/**
 * @swagger
 * /socket.io/connection:
 *   get:
 *     summary: Socket.io Connection
 *     description: WebSocket connection endpoint for real-time communication
 *     tags: [Socket.io Events]
 *     security: []
 *     responses:
 *       101:
 *         description: WebSocket connection established
 *       401:
 *         description: Authentication failed
 */

/**
 * @swagger
 * /socket.io/events/join_room:
 *   post:
 *     summary: Join a chat room
 *     description: Join a specific room to receive real-time messages
 *     tags: [Socket.io Events]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roomId
 *             properties:
 *               roomId:
 *                 type: string
 *                 description: Room ID to join
 *                 example: "60f7b3b3b3b3b3b3b3b3b3b5"
 *     responses:
 *       200:
 *         description: Successfully joined room
 */

/**
 * @swagger
 * /socket.io/events/send_message:
 *   post:
 *     summary: Send encrypted message
 *     description: Send an encrypted message to a user or group
 *     tags: [Socket.io Events]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - encryptedContent
 *               - messageType
 *             properties:
 *               recipientId:
 *                 type: string
 *                 description: Recipient user ID (for direct messages)
 *                 example: "60f7b3b3b3b3b3b3b3b3b3b2"
 *               roomId:
 *                 type: string
 *                 description: Room ID (for group messages)
 *                 example: "60f7b3b3b3b3b3b3b3b3b3b5"
 *               encryptedContent:
 *                 type: string
 *                 description: Encrypted message content (base64)
 *                 example: "U2FsdGVkX1+vupppZksvRf5pq5g5XjFRlipRkwB0K1Y="
 *               messageType:
 *                 type: string
 *                 enum: [text, file, image]
 *                 description: Type of message
 *                 example: text
 *               fileUrl:
 *                 type: string
 *                 nullable: true
 *                 description: File URL (for file messages)
 *                 example: "/uploads/1234567890-123456789.jpg"
 *     responses:
 *       200:
 *         description: Message sent successfully
 */

/**
 * @swagger
 * /socket.io/events/typing_start:
 *   post:
 *     summary: Start typing indicator
 *     description: Notify other users that you are typing
 *     tags: [Socket.io Events]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roomId
 *             properties:
 *               roomId:
 *                 type: string
 *                 description: Room ID where typing is happening
 *                 example: "60f7b3b3b3b3b3b3b3b3b3b5"
 *     responses:
 *       200:
 *         description: Typing indicator sent
 */

/**
 * @swagger
 * /socket.io/events/typing_stop:
 *   post:
 *     summary: Stop typing indicator
 *     description: Stop the typing indicator
 *     tags: [Socket.io Events]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roomId
 *             properties:
 *               roomId:
 *                 type: string
 *                 description: Room ID where typing stopped
 *                 example: "60f7b3b3b3b3b3b3b3b3b3b5"
 *     responses:
 *       200:
 *         description: Typing indicator stopped
 */

/**
 * @swagger
 * components:
 *   schemas:
 *     SocketConnection:
 *       type: object
 *       description: Socket.io connection example
 *       properties:
 *         connection:
 *           type: string
 *           example: "ws://localhost:5000/socket.io/"
 *         authentication:
 *           type: object
 *           properties:
 *             auth:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                   example: "your-jwt-token"
 */
