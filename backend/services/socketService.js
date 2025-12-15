const jwt = require('jsonwebtoken');
const messageService = require('./messageService');

class SocketService {
  constructor(io) {
    this.io = io;
    this.users = new Map(); // userId -> socketId mapping
    this.setupSocketHandlers();
  }

  setupSocketHandlers() {
    this.io.use((socket, next) => {
      try {
        const token = socket.handshake.auth.token;
        
        if (!token) {
          return next(new Error('Authentication error'));
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.userId = decoded.userId;
        next();
      } catch (error) {
        next(new Error('Authentication error'));
      }
    });

    this.io.on('connection', (socket) => {
      console.log(`✓ User connected: ${socket.userId}`);
      
      // Store user connection
      this.users.set(socket.userId, socket.id);
      
      // Emit online status
      socket.broadcast.emit('user_online', { userId: socket.userId });

      // Join personal room
      socket.join(socket.userId);

      // Handle join room (conversation)
      socket.on('join_room', (data) => {
        this.handleJoinRoom(socket, data);
      });

      // Handle send message
      socket.on('send_message', async (data) => {
        await this.handleSendMessage(socket, data);
      });

      // Handle typing indicator
      socket.on('typing', (data) => {
        this.handleTyping(socket, data);
      });

      // Handle disconnect
      socket.on('disconnect', () => {
        this.handleDisconnect(socket);
      });
    });
  }

  handleJoinRoom(socket, data) {
    const { receiverId } = data;
    const roomId = this.getRoomId(socket.userId, receiverId);
    socket.join(roomId);
    console.log(`✓ User ${socket.userId} joined room: ${roomId}`);
  }

  async handleSendMessage(socket, data) {
    try {
      const { receiverId, content, messageType = 'text' } = data;

      // Save encrypted message to database
      const message = await messageService.saveMessage({
        sender: socket.userId,
        receiver: receiverId,
        content, // Already encrypted by client
        messageType
      });

      const roomId = this.getRoomId(socket.userId, receiverId);

      // Emit to room (both sender and receiver)
      this.io.to(roomId).emit('receive_message', {
        id: message._id,
        sender: socket.userId,
        receiver: receiverId,
        content: message.content,
        messageType: message.messageType,
        timestamp: message.timestamp
      });

      // If receiver is online but not in room, send notification
      const receiverSocketId = this.users.get(receiverId);
      if (receiverSocketId) {
        this.io.to(receiverSocketId).emit('new_message_notification', {
          senderId: socket.userId,
          messageType: message.messageType
        });
      }

      console.log(`✓ Message sent: ${socket.userId} -> ${receiverId}`);
    } catch (error) {
      console.error('Send message error:', error);
      socket.emit('message_error', { error: 'Failed to send message' });
    }
  }

  handleTyping(socket, data) {
    const { receiverId, isTyping } = data;
    const receiverSocketId = this.users.get(receiverId);
    
    if (receiverSocketId) {
      this.io.to(receiverSocketId).emit('user_typing', {
        userId: socket.userId,
        isTyping
      });
    }
  }

  handleDisconnect(socket) {
    console.log(`✗ User disconnected: ${socket.userId}`);
    this.users.delete(socket.userId);
    socket.broadcast.emit('user_offline', { userId: socket.userId });
  }

  // Generate consistent room ID for two users
  getRoomId(userId1, userId2) {
    return [userId1, userId2].sort().join('_');
  }
}

module.exports = SocketService;
