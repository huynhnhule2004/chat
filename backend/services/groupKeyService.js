/**
 * ============================================================
 * GROUP KEY SERVICE - E2EE Session Key Distribution
 * ============================================================
 * 
 * Security Model Explanation:
 * 
 * Problem: Group chat with 100 members
 * - Can't encrypt each message 100 times (performance nightmare)
 * - Can't share one key for everyone (breaks E2EE if someone is kicked)
 * 
 * Solution: Shared Session Key with Per-Member Encryption
 * 
 * 1. CREATION PHASE (Admin creates group):
 *    - Admin generates random SessionKey (256-bit AES key)
 *    - Admin uses SessionKey to encrypt group messages
 *    - For distribution: Admin encrypts SessionKey with EACH member's RSA public key
 *    - Server stores encrypted copies (one per member)
 *    - Server NEVER sees the actual SessionKey (always encrypted)
 * 
 * 2. JOIN PHASE (New member joins):
 *    - Admin encrypts SessionKey with new member's public key
 *    - Server stores encrypted copy for new member
 *    - New member decrypts with their private key -> Gets SessionKey
 *    - Now they can decrypt group messages
 * 
 * 3. SEND MESSAGE PHASE:
 *    - Sender encrypts message with SessionKey (once)
 *    - Server broadcasts encrypted message to all members
 *    - Each member decrypts with SessionKey (which they have)
 * 
 * 4. KICK PHASE (Critical Security):
 *    - Problem: Kicked member still has the old SessionKey!
 *    - Solution: KEY ROTATION
 *      a. Admin generates NEW SessionKey
 *      b. Admin re-encrypts it for all REMAINING members
 *      c. Update sessionKeyVersion
 *      d. Delete kicked member's entry
 *    - Kicked member can't decrypt new messages (has old key)
 * 
 * Analogy (The Lock & Dictionary):
 * - Room Password = Outer door lock (server checks)
 * - Session Key = Secret dictionary to understand messages
 * - When you join: Admin puts dictionary in a safe (encrypted with YOUR key)
 * - Only you can open the safe (with your private key)
 * - When someone is kicked: Admin burns the old dictionary and gives everyone a new one
 */

const crypto = require('crypto');
const User = require('../models/User');

class GroupKeyService {
  
  /**
   * Generate a random Session Key (256-bit AES key)
   * This key will be used to encrypt/decrypt group messages
   * 
   * @returns {string} Base64-encoded 256-bit key
   */
  static generateSessionKey() {
    // Generate 32 bytes (256 bits) for AES-256
    const sessionKey = crypto.randomBytes(32);
    return sessionKey.toString('base64');
  }

  /**
   * Encrypt Session Key with user's RSA public key
   * 
   * @param {string} sessionKey - Base64 encoded session key
   * @param {string} userPublicKey - User's RSA public key (PEM format)
   * @returns {string} Base64 encoded encrypted session key
   * 
   * Flow:
   * 1. User has RSA key pair: publicKey (stored on server), privateKey (stored on client)
   * 2. Admin encrypts SessionKey with user's publicKey
   * 3. Result: Only user can decrypt with their privateKey
   */
  static encryptSessionKey(sessionKey, userPublicKey) {
    try {
      // Convert base64 session key to buffer
      const sessionKeyBuffer = Buffer.from(sessionKey, 'base64');
      
      // Encrypt with RSA-OAEP (optimal asymmetric encryption padding)
      const encrypted = crypto.publicEncrypt(
        {
          key: userPublicKey,
          padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
          oaepHash: 'sha256'
        },
        sessionKeyBuffer
      );
      
      return encrypted.toString('base64');
    } catch (error) {
      console.error('Encrypt session key error:', error);
      throw new Error('Failed to encrypt session key');
    }
  }

  /**
   * Prepare encrypted session keys for multiple members
   * Called when creating group or adding members
   * 
   * @param {string} sessionKey - The group's session key
   * @param {Array<string>} userIds - Array of user IDs to encrypt for
   * @returns {Promise<Array>} Array of { userId, encryptedKey, publicKey }
   * 
   * Example Usage (Create Group):
   * ```
   * const sessionKey = GroupKeyService.generateSessionKey();
   * const memberIds = ['user1', 'user2', 'user3'];
   * const encryptedKeys = await GroupKeyService.encryptSessionKeyForMembers(
   *   sessionKey, 
   *   memberIds
   * );
   * // Store encryptedKeys in RoomMember collection
   * ```
   */
  static async encryptSessionKeyForMembers(sessionKey, userIds) {
    try {
      const encryptedKeys = [];
      
      for (const userId of userIds) {
        // Fetch user's public key from database
        const user = await User.findById(userId).select('publicKey');
        
        if (!user || !user.publicKey) {
          console.warn(`User ${userId} does not have a public key`);
          continue; // Skip this user
        }
        
        // Encrypt session key with user's public key
        const encryptedKey = this.encryptSessionKey(sessionKey, user.publicKey);
        
        encryptedKeys.push({
          userId,
          encryptedKey,
          publicKey: user.publicKey
        });
      }
      
      return encryptedKeys;
    } catch (error) {
      console.error('Encrypt session key for members error:', error);
      throw new Error('Failed to encrypt session keys for members');
    }
  }

  /**
   * Verify session key version
   * Check if user has the latest key version
   * 
   * @param {number} userKeyVersion - User's current key version
   * @param {number} roomKeyVersion - Room's current key version
   * @returns {boolean} True if user has latest key
   */
  static isKeyVersionValid(userKeyVersion, roomKeyVersion) {
    return userKeyVersion === roomKeyVersion;
  }

  /**
   * Key Rotation Helper
   * Generate new session key and prepare encrypted copies for remaining members
   * Called after kicking a member
   * 
   * @param {Array<string>} remainingMemberIds - IDs of members who should get new key
   * @returns {Promise<Object>} { newSessionKey, encryptedKeys }
   * 
   * Example Usage (Kick Member):
   * ```
   * // 1. Remove kicked member from room
   * await room.removeMember(kickedUserId);
   * 
   * // 2. Get remaining members
   * const remainingMembers = room.members.filter(id => id !== kickedUserId);
   * 
   * // 3. Rotate key
   * const { newSessionKey, encryptedKeys } = await GroupKeyService.rotateSessionKey(
   *   remainingMembers
   * );
   * 
   * // 4. Update RoomMember entries
   * for (const { userId, encryptedKey } of encryptedKeys) {
   *   await RoomMember.updateSessionKey(userId, encryptedKey, newKeyVersion);
   * }
   * 
   * // 5. Increment room's sessionKeyVersion
   * await room.rotateSessionKey();
   * ```
   */
  static async rotateSessionKey(remainingMemberIds) {
    try {
      // Generate new session key
      const newSessionKey = this.generateSessionKey();
      
      // Encrypt for all remaining members
      const encryptedKeys = await this.encryptSessionKeyForMembers(
        newSessionKey, 
        remainingMemberIds
      );
      
      return {
        newSessionKey,
        encryptedKeys
      };
    } catch (error) {
      console.error('Rotate session key error:', error);
      throw new Error('Failed to rotate session key');
    }
  }

  /**
   * Encrypt group message with session key
   * This is a HELPER for demonstration - actual encryption happens on CLIENT side
   * 
   * @param {string} plaintext - Message content
   * @param {string} sessionKey - Base64 encoded session key
   * @returns {Object} { encryptedContent, iv }
   */
  static encryptMessage(plaintext, sessionKey) {
    try {
      // Generate random IV (Initialization Vector)
      const iv = crypto.randomBytes(16);
      
      // Convert session key from base64 to buffer
      const keyBuffer = Buffer.from(sessionKey, 'base64');
      
      // Create cipher (AES-256-GCM for authenticated encryption)
      const cipher = crypto.createCipheriv('aes-256-gcm', keyBuffer, iv);
      
      // Encrypt
      let encrypted = cipher.update(plaintext, 'utf8', 'base64');
      encrypted += cipher.final('base64');
      
      // Get auth tag for integrity verification
      const authTag = cipher.getAuthTag().toString('base64');
      
      return {
        encryptedContent: encrypted,
        iv: iv.toString('base64'),
        authTag
      };
    } catch (error) {
      console.error('Encrypt message error:', error);
      throw new Error('Failed to encrypt message');
    }
  }

  /**
   * Decrypt group message with session key
   * This is a HELPER for demonstration - actual decryption happens on CLIENT side
   * 
   * @param {string} encryptedContent - Base64 encoded encrypted message
   * @param {string} sessionKey - Base64 encoded session key
   * @param {string} iv - Base64 encoded initialization vector
   * @param {string} authTag - Base64 encoded authentication tag
   * @returns {string} Plaintext message
   */
  static decryptMessage(encryptedContent, sessionKey, iv, authTag) {
    try {
      // Convert from base64
      const keyBuffer = Buffer.from(sessionKey, 'base64');
      const ivBuffer = Buffer.from(iv, 'base64');
      const authTagBuffer = Buffer.from(authTag, 'base64');
      
      // Create decipher
      const decipher = crypto.createDecipheriv('aes-256-gcm', keyBuffer, ivBuffer);
      decipher.setAuthTag(authTagBuffer);
      
      // Decrypt
      let decrypted = decipher.update(encryptedContent, 'base64', 'utf8');
      decrypted += decipher.final('utf8');
      
      return decrypted;
    } catch (error) {
      console.error('Decrypt message error:', error);
      throw new Error('Failed to decrypt message');
    }
  }

  /**
   * Validate that user can decrypt with their version of session key
   * Used for debugging/testing
   * 
   * @param {string} encryptedSessionKey - User's encrypted session key
   * @param {string} userPrivateKey - User's RSA private key (only available on client!)
   * @returns {string} Decrypted session key
   */
  static decryptSessionKeyForUser(encryptedSessionKey, userPrivateKey) {
    try {
      const encryptedBuffer = Buffer.from(encryptedSessionKey, 'base64');
      
      const decrypted = crypto.privateDecrypt(
        {
          key: userPrivateKey,
          padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
          oaepHash: 'sha256'
        },
        encryptedBuffer
      );
      
      return decrypted.toString('base64');
    } catch (error) {
      console.error('Decrypt session key error:', error);
      throw new Error('Failed to decrypt session key');
    }
  }
}

module.exports = GroupKeyService;
