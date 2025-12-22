const mongoose = require('mongoose');

/**
 * Room Schema for Group Chat
 * 
 * Security Design:
 * - passwordHash: bcrypt hash, never store plain-text password
 * - sessionKeyVersion: Increments when key is rotated (e.g., after kicking member)
 * - Each member stores their own encrypted copy of the session key
 * 
 * Key Distribution Flow:
 * 1. Admin creates group -> generates random SessionKey
 * 2. Admin encrypts SessionKey with each member's public key
 * 3. Server stores encrypted copies (one per member)
 * 4. When user joins, server sends their encrypted copy
 * 5. User decrypts with their private key -> Gets SessionKey
 */
const roomSchema = new mongoose.Schema({
  // Room metadata
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100
  },
  
  type: {
    type: String,
    enum: ['group', 'channel'], // 'group' for group chat, 'channel' for broadcast
    default: 'group',
    required: true
  },
  
  avatar: {
    type: String, // URL to group avatar
    default: null
  },
  
  description: {
    type: String,
    maxlength: 500,
    default: ''
  },
  
  // Owner/Admin management
  ownerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Password protection
  passwordHash: {
    type: String, // bcrypt hash of room password
    default: null // null = public room (no password required)
  },
  
  isPasswordProtected: {
    type: Boolean,
    default: false
  },
  
  // Members
  members: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  
  memberCount: {
    type: Number,
    default: 0
  },
  
  // E2EE Key Management
  sessionKeyVersion: {
    type: Number,
    default: 1,
    // Increments every time we rotate the key (e.g., after kicking a member)
    // Clients can check if they have the latest key version
  },
  
  // Settings
  settings: {
    allowMembersToInvite: {
      type: Boolean,
      default: true
    },
    allowMembersToAddMembers: {
      type: Boolean,
      default: false // Only admin can add by default
    },
    maxMembers: {
      type: Number,
      default: 500
    }
  },
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now
  },
  
  updatedAt: {
    type: Date,
    default: Date.now
  },
  
  lastMessageAt: {
    type: Date,
    default: Date.now
  }
});

// Indexes for performance
roomSchema.index({ ownerId: 1 });
roomSchema.index({ members: 1 });
roomSchema.index({ createdAt: -1 });
roomSchema.index({ lastMessageAt: -1 });

// Update timestamp before saving
roomSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Methods
roomSchema.methods = {
  // Check if user is member
  isMember(userId) {
    return this.members.some(memberId => memberId.toString() === userId.toString());
  },
  
  // Check if user is owner
  isOwner(userId) {
    return this.ownerId.toString() === userId.toString();
  },
  
  // Add member to room
  async addMember(userId) {
    if (!this.isMember(userId)) {
      this.members.push(userId);
      this.memberCount = this.members.length;
      await this.save();
    }
  },
  
  // Remove member from room
  async removeMember(userId) {
    const index = this.members.findIndex(memberId => memberId.toString() === userId.toString());
    if (index > -1) {
      this.members.splice(index, 1);
      this.memberCount = this.members.length;
      await this.save();
    }
  },
  
  // Rotate key version (after kicking member)
  async rotateSessionKey() {
    this.sessionKeyVersion += 1;
    await this.save();
  }
};

// Statics
roomSchema.statics = {
  // Get rooms where user is member
  async getUserRooms(userId) {
    return this.find({ members: userId })
      .populate('ownerId', 'username email avatar')
      .sort({ lastMessageAt: -1 });
  },
  
  // Get public rooms (no password)
  async getPublicRooms(limit = 20, skip = 0) {
    return this.find({ 
      isPasswordProtected: false,
      isPrivate: false  // Only show truly public groups
    })
      .populate('ownerId', 'username email avatar')
      .limit(limit)
      .skip(skip)
      .sort({ memberCount: -1, createdAt: -1 });
  }
};

module.exports = mongoose.model('Room', roomSchema);
