const mongoose = require('mongoose');

/**
 * RoomMember Schema - Stores Encrypted Session Keys per Member
 * 
 * Critical Security Component:
 * Each member has their own encrypted copy of the room's SessionKey.
 * 
 * Key Distribution Process:
 * 1. Admin generates SessionKey (256-bit AES key)
 * 2. For each member, encrypt SessionKey with their RSA public key:
 *    encryptedSessionKey = RSA_Encrypt(sessionKey, memberPublicKey)
 * 3. Store each encrypted copy in this collection
 * 4. When member joins, send them their encrypted copy
 * 5. Member decrypts: sessionKey = RSA_Decrypt(encryptedSessionKey, memberPrivateKey)
 * 
 * Key Rotation (after kicking member):
 * 1. Admin generates NEW SessionKey
 * 2. Delete kicked member's RoomMember entry
 * 3. For remaining members, encrypt new SessionKey and update encryptedSessionKey
 * 4. Increment room's sessionKeyVersion
 * 5. Kicked member can't decrypt new messages (has old key)
 */
const roomMemberSchema = new mongoose.Schema({
  // References
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room',
    required: true
  },
  
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // E2EE Key Storage
  encryptedSessionKey: {
    type: String,
    required: true,
    // This is the SessionKey encrypted with the member's PUBLIC key
    // Format: Base64-encoded RSA-OAEP encrypted data
    // Only this specific user can decrypt it with their PRIVATE key
  },
  
  sessionKeyVersion: {
    type: Number,
    required: true,
    default: 1,
    // Must match Room.sessionKeyVersion
    // If user's version < room's version, they need to fetch new key
  },
  
  // Member role and permissions
  role: {
    type: String,
    enum: ['owner', 'admin', 'member'],
    default: 'member'
  },
  
  // Member metadata
  joinedAt: {
    type: Date,
    default: Date.now
  },
  
  lastSeenMessageId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null
  },
  
  unreadCount: {
    type: Number,
    default: 0
  },
  
  // Notification settings
  isMuted: {
    type: Boolean,
    default: false
  },
  
  mutedUntil: {
    type: Date,
    default: null
  },
  
  // Status
  isActive: {
    type: Boolean,
    default: true
    // False if kicked/left. Keep record for history but don't send messages
  },
  
  leftAt: {
    type: Date,
    default: null
  }
});

// Compound indexes for efficient queries
roomMemberSchema.index({ roomId: 1, userId: 1 }, { unique: true });
roomMemberSchema.index({ userId: 1, isActive: 1 });
roomMemberSchema.index({ roomId: 1, isActive: 1 });

// Methods
roomMemberSchema.methods = {
  // Check if member has latest key version
  hasLatestKey(roomKeyVersion) {
    return this.sessionKeyVersion === roomKeyVersion;
  },
  
  // Update session key (during key rotation)
  async updateSessionKey(newEncryptedKey, newVersion) {
    this.encryptedSessionKey = newEncryptedKey;
    this.sessionKeyVersion = newVersion;
    await this.save();
  },
  
  // Mark as left/kicked
  async deactivate() {
    this.isActive = false;
    this.leftAt = Date.now();
    await this.save();
  }
};

// Statics
roomMemberSchema.statics = {
  // Get member's encrypted key for a room
  async getMemberKey(roomId, userId) {
    return this.findOne({ 
      roomId, 
      userId, 
      isActive: true 
    });
  },
  
  // Get all active members of a room with their keys
  async getRoomMembers(roomId) {
    return this.find({ roomId, isActive: true })
      .populate('userId', 'username email avatar publicKey')
      .sort({ joinedAt: 1 });
  },
  
  // Get rooms for a user
  async getUserRooms(userId) {
    return this.find({ userId, isActive: true })
      .populate({
        path: 'roomId',
        populate: {
          path: 'ownerId',
          select: 'username email avatar'
        }
      })
      .sort({ 'roomId.lastMessageAt': -1 });
  },
  
  // Bulk create member entries (when creating room or adding multiple members)
  async createMemberEntries(entries) {
    // entries = [{ roomId, userId, encryptedSessionKey, sessionKeyVersion, role }]
    return this.insertMany(entries);
  },
  
  // Delete member entry (when kicked or left)
  async removeMember(roomId, userId) {
    return this.findOneAndUpdate(
      { roomId, userId },
      { isActive: false, leftAt: Date.now() }
    );
  }
};

module.exports = mongoose.model('RoomMember', roomMemberSchema);
