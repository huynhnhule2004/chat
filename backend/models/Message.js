const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  receiver: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null // null for group messages
  },

  // Group chat support
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room',
    default: null // null for 1-1 messages
  },
  content: {
    type: String,
    required: true // Encrypted content (AES-256-GCM)
  },
  messageType: {
    type: String,
    enum: ['text', 'image', 'video', 'file'],
    default: 'text'
  },
  // E2EE fields for group chat (AES-GCM)
  iv: {
    type: String, // Initialization vector for AES-GCM
    default: null
  },

  authTag: {
    type: String, // Authentication tag for AES-GCM integrity check
    default: null
  },

  timestamp: {
    type: Date,
    default: Date.now
  },
  // Forward message fields
  isForwarded: {
    type: Boolean,
    default: false
  },
  originalSenderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: false // Only set if message is forwarded
  },
  forwardedFrom: {
    type: String,
    required: false // Original sender's username (for display)
  },
  // File encryption fields (for hybrid encryption)
  fileUrl: {
    type: String,
    required: false // S3/MinIO URL for media files
  },
  encryptedFileKey: {
    type: String,
    required: false // File symmetric key, encrypted with recipient's public key
  },
  fileSize: {
    type: Number,
    required: false
  }
});

// Create compound index for efficient querying
MessageSchema.index({ sender: 1, receiver: 1, timestamp: -1 });
MessageSchema.index({ timestamp: 1 }); // For cleanup

module.exports = mongoose.model('Message', MessageSchema);
