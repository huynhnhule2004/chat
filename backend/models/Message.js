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
    required: true
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
  timestamp: {
    type: Date,
    default: Date.now
  }
});

// Create compound index for efficient querying
MessageSchema.index({ sender: 1, receiver: 1, timestamp: -1 });
MessageSchema.index({ timestamp: 1 }); // For cleanup

module.exports = mongoose.model('Message', MessageSchema);
