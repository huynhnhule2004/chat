const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const messageService = require('../services/messageService');

/**
 * @swagger
 * tags:
 *   name: Messages
 *   description: Direct message management endpoints
 */

/**
 * @swagger
 * /api/messages/{userId}:
 *   get:
 *     summary: Get messages between two users
 *     description: Retrieve encrypted messages between current user and specified user
 *     tags: [Messages]
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: Target user ID
 *         example: 60f7b3b3b3b3b3b3b3b3b3b3
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Number of messages to retrieve
 *         example: 20
 *       - in: query
 *         name: skip
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Number of messages to skip (for pagination)
 *         example: 0
 *     responses:
 *       200:
 *         description: Messages retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 messages:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Message'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
// Get messages between two users
router.get('/:userId', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, skip = 0 } = req.query;

    const messages = await messageService.getMessages(
      req.userId,
      userId,
      parseInt(limit),
      parseInt(skip)
    );

    res.json({ messages });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

/**
 * @swagger
 * /api/messages:
 *   get:
 *     summary: Get all conversations
 *     description: Retrieve all conversations for the current user
 *     tags: [Messages]
 *     responses:
 *       200:
 *         description: Conversations retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 conversations:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       _id:
 *                         type: string
 *                         description: Conversation ID
 *                       participant:
 *                         $ref: '#/components/schemas/User'
 *                       lastMessage:
 *                         $ref: '#/components/schemas/Message'
 *                       unreadCount:
 *                         type: integer
 *                         description: Number of unread messages
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
// Get all conversations for current user
router.get('/', authMiddleware, async (req, res) => {
  try {
    const conversations = await messageService.getConversations(req.userId);
    res.json({ conversations });
  } catch (error) {
    console.error('Get conversations error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

/**
 * @swagger
 * /api/messages:
 *   post:
 *     summary: Gửi tin nhắn mới
 *     description: |
 *       Gửi tin nhắn đã mã hóa E2EE. Client phải mã hóa nội dung trước khi gửi.
 *       
 *       **Lưu ý**: Tin nhắn sẽ được gửi realtime qua WebSocket đến người nhận.
 *     tags: [Messages]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [encryptedContent, messageType]
 *             properties:
 *               recipientId:
 *                 type: string
 *                 description: ID người nhận (cho tin nhắn trực tiếp)
 *                 example: 60f7b3b3b3b3b3b3b3b3b3b5
 *               roomId:
 *                 type: string
 *                 description: ID room/group (cho tin nhắn nhóm)
 *                 example: 60f7b3b3b3b3b3b3b3b3b3b6
 *               encryptedContent:
 *                 type: string
 *                 description: Nội dung tin nhắn đã mã hóa AES
 *                 example: U2FsdGVkX1+vupppZksvRf5pq5g5XjFRlipRkwB0K1Y=
 *               messageType:
 *                 type: string
 *                 enum: [text, file, image, voice]
 *                 description: Loại tin nhắn
 *                 example: text
 *               fileUrl:
 *                 type: string
 *                 description: URL file đính kèm (nếu messageType là file/image)
 *                 example: /uploads/1234567890-document.pdf
 *     responses:
 *       201:
 *         description: Tin nhắn được gửi thành công
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Message sent successfully
 *                 messageData:
 *                   $ref: '#/components/schemas/Message'
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       404:
 *         description: Người nhận hoặc room không tồn tại
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
// Send a new message
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { recipientId, roomId, encryptedContent, messageType, fileUrl } = req.body;

    // Validate request body
    if (!encryptedContent || !messageType) {
      return res.status(400).json({ error: 'Encrypted content and message type are required' });
    }

    // Check if recipient or room exists
    const recipientExists = await messageService.checkUserExists(recipientId);
    const roomExists = roomId ? await messageService.checkRoomExists(roomId) : true;

    if (!recipientExists && !roomExists) {
      return res.status(404).json({ error: 'Recipient or room not found' });
    }

    // Save the message
    const messageData = await messageService.saveMessage({
      senderId: req.userId,
      recipientId,
      roomId,
      encryptedContent,
      messageType,
      fileUrl,
    });

    res.status(201).json({ message: 'Message sent successfully', messageData });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
