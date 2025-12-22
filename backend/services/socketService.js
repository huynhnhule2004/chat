const jwt = require('jsonwebtoken');
const messageService = require('./messageService');
const User = require('../models/User');
const Room = require('../models/Room');
const RoomMember = require('../models/RoomMember');

class SocketService {
  constructor(io) {
    console.log('🚀 SocketService initializing...');
    this.io = io;
    this.users = new Map(); // userId -> socketId mapping
    this.setupSocketHandlers();
    console.log('✅ SocketService initialized successfully');
  }

  setupSocketHandlers() {
    console.log('📡 Setting up Socket.IO handlers...');
    
    this.io.use(async (socket, next) => {
      try {
        console.log('🔍 Socket connection attempt...');
        const token = socket.handshake.auth.token;
        
        if (!token) {
          console.log('❌ No token provided');
          return next(new Error('Authentication error'));
        }

        console.log('🔑 Verifying token...');
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        console.log('✅ Token verified for user:', decoded.userId);
        
        // Check if user is banned
        const user = await User.findById(decoded.userId);
        if (!user) {
          console.log('❌ User not found:', decoded.userId);
          return next(new Error('User not found'));
        }
        
        if (user.isBanned) {
          console.log('❌ User is banned:', decoded.userId);
          return next(new Error('Account is banned'));
        }
        
        socket.userId = decoded.userId;
        console.log('✅ Socket authenticated for user:', socket.userId);
        next();
      } catch (error) {
        console.log('❌ Socket auth error:', error.message);
        next(new Error('Authentication error'));
      }
    });

    console.log('🎧 Registering connection listener...');
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

      // ====== GROUP CHAT HANDLERS ======
      
      // Join group room
      socket.on('join_group', async (data) => {
        await this.handleJoinGroup(socket, data);
      });

      // Send group message
      socket.on('send_group_message', async (data) => {
        await this.handleSendGroupMessage(socket, data);
      });

      // Leave group room
      socket.on('leave_group', (data) => {
        this.handleLeaveGroup(socket, data);
      });

      // Group typing indicator
      socket.on('group_typing', (data) => {
        this.handleGroupTyping(socket, data);
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
      const { 
        receiverId, 
        content, 
        messageType = 'text',
        isForwarded = false,
        originalSenderId,
        forwardedFrom,
        fileUrl,
        encryptedFileKey,
      } = data;

      // Save encrypted message to database (with forward fields)
      const message = await messageService.saveMessage({
        sender: socket.userId,
        receiver: receiverId,
        content, // Already encrypted by client
        messageType,
        isForwarded,
        originalSenderId,
        forwardedFrom,
        fileUrl,
        encryptedFileKey,
      });

      const roomId = this.getRoomId(socket.userId, receiverId);

      // Emit to room (both sender and receiver)
      this.io.to(roomId).emit('receive_message', {
        id: message._id,
        sender: socket.userId,
        receiver: receiverId,
        content: message.content,
        messageType: message.messageType,
        timestamp: message.timestamp,
        isForwarded: message.isForwarded,
        originalSenderId: message.originalSenderId,
        forwardedFrom: message.forwardedFrom,
        fileUrl: message.fileUrl,
        encryptedFileKey: message.encryptedFileKey,
      });

      // If receiver is online but not in room, send notification
      const receiverSocketId = this.users.get(receiverId);
      if (receiverSocketId) {
        this.io.to(receiverSocketId).emit('new_message_notification', {
          senderId: socket.userId,
          messageType: message.messageType,
          isForwarded: message.isForwarded,
        });
      }

      console.log(`✓ Message sent: ${socket.userId} -> ${receiverId} ${isForwarded ? '(forwarded)' : ''}`);
    } catch (error) {
      console.error('Send message error:', error);
      socket.emit('message_error', { error: 'Failed to send message' });
    }
  }


  // ============================================================
  // GROUP CHAT SOCKET HANDLERS
  // ============================================================

  /**
   * Handle user joining a group room
   * User must be verified as group member before joining socket room
   */
  async handleJoinGroup(socket, data) {
    try {
      const { roomId } = data;
      const userId = socket.userId;

      // Verify user is member of this group
      const room = await Room.findById(roomId);
      if (!room) {
        socket.emit('group_error', { error: 'Group not found' });
        return;
      }

      if (!room.isMember(userId)) {
        socket.emit('group_error', { error: 'You are not a member of this group' });
        return;
      }

      // Join socket room
      socket.join(roomId);
      
      // Notify other members
      socket.to(roomId).emit('member_joined', {
        roomId,
        userId,
        timestamp: Date.now()
      });

      console.log(`✓ User ${userId} joined group: ${roomId}`);
    } catch (error) {
      console.error('Join group error:', error);
      socket.emit('group_error', { error: 'Failed to join group' });
    }
  }

  /**
   * Handle sending message to group
   * Message is already encrypted with SessionKey by client
   */
  async handleSendGroupMessage(socket, data) {
    try {
      const { 
        roomId,
        content, // Encrypted with SessionKey
        messageType = 'text',
        iv, // Initialization vector for AES-GCM
        authTag, // Authentication tag for integrity
        fileUrl,
        encryptedFileKey,
        isForwarded = false,
        originalSenderId,
        forwardedFrom
      } = data;

      const userId = socket.userId;

      // Verify user is member
      const room = await Room.findById(roomId);
      if (!room || !room.isMember(userId)) {
        socket.emit('group_error', { error: 'Unauthorized' });
        return;
      }

      // Save message to database
      const Message = require('../models/Message');
      const message = new Message({
        sender: userId,
        receiver: null, // Group messages don't have single receiver
        roomId, // Group room ID
        content, // Encrypted content
        messageType,
        iv,
        authTag,
        fileUrl,
        encryptedFileKey,
        isForwarded,
        originalSenderId,
        forwardedFrom,
        timestamp: new Date()
      });

      await message.save();

      // Update room's last message time
      room.lastMessageAt = Date.now();
      await room.save();

      // Populate sender info
      const sender = await User.findById(userId).select('username email avatar');

      // Broadcast to all members in the room
      this.io.to(roomId).emit('receive_group_message', {
        id: message._id,
        roomId,
        sender: {
          id: sender._id,
          username: sender.username,
          email: sender.email,
          avatar: sender.avatar
        },
        content: message.content,
        messageType: message.messageType,
        iv: message.iv,
        authTag: message.authTag,
        fileUrl: message.fileUrl,
        encryptedFileKey: message.encryptedFileKey,
        isForwarded: message.isForwarded,
        originalSenderId: message.originalSenderId,
        forwardedFrom: message.forwardedFrom,
        timestamp: message.timestamp
      });

      console.log(`✓ Group message sent: ${userId} -> ${roomId} ${isForwarded ? '(forwarded)' : ''}`);
    } catch (error) {
      console.error('Send group message error:', error);
      socket.emit('group_error', { error: 'Failed to send message' });
    }
  }

  /**
   * Handle user leaving group room (socket disconnect from room)
   */
  handleLeaveGroup(socket, data) {
    try {
      const { roomId } = data;
      socket.leave(roomId);
      
      // Notify others
      socket.to(roomId).emit('member_left', {
        roomId,
        userId: socket.userId,
        timestamp: Date.now()
      });

      console.log(`✓ User ${socket.userId} left group: ${roomId}`);
    } catch (error) {
      console.error('Leave group error:', error);
    }
  }

  /**
   * Handle typing indicator for group chat
   */
  handleGroupTyping(socket, data) {
    try {
      const { roomId, isTyping } = data;
      const userId = socket.userId;

      // Broadcast to room (excluding sender)
      socket.to(roomId).emit('group_user_typing', {
        roomId,
        userId,
        isTyping
      });
    } catch (error) {
      console.error('Group typing error:', error);
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
