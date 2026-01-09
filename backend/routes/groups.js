const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const Room = require('../models/Room');
const RoomMember = require('../models/RoomMember');
const User = require('../models/User');
const Message = require('../models/Message');
const auth = require('../middleware/auth');

/**
 * @swagger
 * tags:
 *   name: Groups
 *   description: Group chat management endpoints with E2EE support
 */

/**
 * ============================================================
 * GROUP CHAT API ROUTES
 * ============================================================
 * 
 * Security Architecture:
 * - Password: Server validates using bcrypt (outer door lock)
 * - SessionKey: Client-side E2EE (inner encryption dictionary)
 * - Key Distribution: Encrypted per member using their public key
 * 
 * Flow Summary:
 * 1. Create Group -> Admin sends encrypted keys for initial members
 * 2. Join Group -> Validate password -> Return user's encrypted key
 * 3. Send Message -> Encrypted with SessionKey (client-side)
 * 4. Kick Member -> Rotate SessionKey -> Re-encrypt for remaining members
 */

/**
 * @swagger
 * /api/groups/create:
 *   post:
 *     summary: Create a new group chat
 *     description: |
 *       Create a new group chat with E2EE support. The client must generate a session key 
 *       and encrypt it for each initial member using their RSA public keys.
 *     tags: [Groups]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - encryptedSessionKeys
 *             properties:
 *               name:
 *                 type: string
 *                 description: Group name
 *               avatar:
 *                 type: string
 *                 description: Group avatar URL
 *               description:
 *                 type: string
 *                 description: Group description
 *               password:
 *                 type: string
 *                 description: Optional password protection
 *               initialMembers:
 *                 type: array
 *                 items:
 *                   type: string
 *                 description: Array of user IDs to add as initial members
 *               encryptedSessionKeys:
 *                 type: array
 *                 description: Session keys encrypted for each member
 *                 items:
 *                   type: object
 *                   properties:
 *                     userId:
 *                       type: string
 *                     encryptedKey:
 *                       type: string
 *     responses:
 *       201:
 *         description: Group created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 room:
 *                   $ref: '#/components/schemas/Room'
 *                 myEncryptedKey:
 *                   type: string
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
/**
 * POST /api/groups/create
 * Create a new group chat
 * 
 * Request Body:
 * {
 *   name: "My Group",
 *   avatar: "https://...",
 *   description: "Group description",
 *   password: "optional_password",  // null for public group
 *   initialMembers: ["userId1", "userId2"],  // Can be empty
 *   encryptedSessionKeys: [
 *     { userId: "userId1", encryptedKey: "base64_encrypted_key" },
 *     { userId: "userId2", encryptedKey: "base64_encrypted_key" }
 *   ]
 * }
 * 
 * Client Responsibility:
 * 1. Generate random SessionKey (256-bit)
 * 2. For each member, encrypt SessionKey with their RSA public key
 * 3. Send encrypted keys in encryptedSessionKeys array
 */
router.post('/create', auth, async (req, res) => {
  try {
    const { name, avatar, description, password, initialMembers, encryptedSessionKeys } = req.body;
    const ownerId = req.userId;

    // Validation
    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: 'Group name is required' });
    }

    if (!encryptedSessionKeys || !Array.isArray(encryptedSessionKeys)) {
      return res.status(400).json({ error: 'Encrypted session keys are required' });
    }

    // Hash password if provided
    let passwordHash = null;
    let isPasswordProtected = false;
    if (password && password.trim().length > 0) {
      passwordHash = await bcrypt.hash(password, 10);
      isPasswordProtected = true;
    }

    // Prepare members array (owner + initial members)
    const members = [ownerId];
    if (initialMembers && Array.isArray(initialMembers)) {
      initialMembers.forEach(memberId => {
        if (!members.includes(memberId)) {
          members.push(memberId);
        }
      });
    }

    // Create room
    const room = new Room({
      name: name.trim(),
      avatar: avatar || null,
      description: description || '',
      type: 'group',
      ownerId,
      passwordHash,
      isPasswordProtected,
      members,
      memberCount: members.length,
      sessionKeyVersion: 1
    });

    await room.save();

    // Create RoomMember entries with encrypted keys
    const roomMemberEntries = encryptedSessionKeys.map(({ userId, encryptedKey }) => ({
      roomId: room._id,
      userId,
      encryptedSessionKey: encryptedKey,
      sessionKeyVersion: 1,
      role: userId === ownerId ? 'owner' : 'member'
    }));

    await RoomMember.createMemberEntries(roomMemberEntries);

    // Populate owner info for response
    await room.populate('ownerId', 'username email avatar');

    res.status(201).json({
      message: 'Group created successfully',
      room: {
        id: room._id,
        name: room.name,
        avatar: room.avatar,
        description: room.description,
        type: room.type,
        owner: room.ownerId,
        memberCount: room.memberCount,
        isPasswordProtected: room.isPasswordProtected,
        sessionKeyVersion: room.sessionKeyVersion,
        createdAt: room.createdAt
      }
    });

  } catch (error) {
    console.error('Create group error:', error);
    res.status(500).json({ error: 'Failed to create group' });
  }
});

/**
 * POST /api/groups/join
 * Join a group (password validation)
 * 
 * Request Body:
 * {
 *   roomId: "room_id",
 *   password: "room_password",  // null if public room
 *   encryptedSessionKey: "base64_encrypted_key"  // Encrypted with user's public key
 * }
 * 
 * Flow:
 * 1. User finds group and wants to join
 * 2. If password protected, show password dialog
 * 3. User submits password
 * 4. Server validates password (bcrypt compare)
 * 5. If valid, admin must have already created encryptedSessionKey for this user
 * 6. Return user's encrypted key + room info
 */
router.post('/join', auth, async (req, res) => {
  try {
    const { roomId, password } = req.body;
    const userId = req.userId;

    // Find room
    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Check if already member
    if (room.isMember(userId)) {
      return res.status(400).json({ error: 'You are already a member of this group' });
    }

    // Validate password if room is password protected
    if (room.isPasswordProtected) {
      if (!password) {
        return res.status(400).json({ error: 'Password is required' });
      }

      const isValidPassword = await bcrypt.compare(password, room.passwordHash);
      if (!isValidPassword) {
        return res.status(401).json({ error: 'Incorrect password' });
      }
    }

    // Check if owner has already created encrypted session key for this user
    const existingMember = await RoomMember.findOne({ roomId: room._id, userId });
    
    if (existingMember && existingMember.encryptedSessionKey) {
      // User was pre-added by owner with encrypted key
      if (!room.members.includes(userId)) {
        await room.addMember(userId);
      }

      existingMember.joinedAt = new Date();
      await existingMember.save();

      res.json({
        message: 'Joined group successfully',
        encryptedSessionKey: existingMember.encryptedSessionKey,
        room: {
          id: room._id,
          name: room.name,
          avatar: room.avatar,
          description: room.description,
          memberCount: room.memberCount,
        }
      });
    } else if (!room.isPasswordProtected && !room.isPrivate) {
      // Public group - allow join without pre-invitation
      await room.addMember(userId);

      // Create pending member entry (no encrypted key yet)
      const roomMember = new RoomMember({
        roomId: room._id,
        userId,
        encryptedSessionKey: null,
        sessionKeyVersion: room.sessionKeyVersion,
        role: 'member',
        joinedAt: new Date()
      });

      await roomMember.save();

      res.json({
        message: 'Joined group successfully. Messages will be available after owner grants access.',
        pending: true,
        room: {
          id: room._id,
          name: room.name,
          avatar: room.avatar,
          description: room.description,
          memberCount: room.memberCount,
        }
      });
    } else {
      // Private or password-protected group requires pre-invitation
      return res.status(403).json({ 
        error: 'You have not been invited to this group. The owner must add you first.' 
      });
    }

  } catch (error) {
    console.error('Join group error:', error);
    res.status(500).json({ error: 'Failed to join group' });
  }
});

/**
 * GET /api/groups/:roomId
 * Get room details and user's encrypted session key
 */
router.get('/:roomId', auth, async (req, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.userId;

    const room = await Room.findById(roomId).populate('ownerId', 'username email avatar');
    if (!room) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Check if user is member
    if (!room.isMember(userId)) {
      return res.status(403).json({ error: 'You are not a member of this group' });
    }

    // Get user's encrypted session key
    const roomMember = await RoomMember.getMemberKey(roomId, userId);
    if (!roomMember) {
      return res.status(404).json({ error: 'Member key not found' });
    }

    // Get all members
    const members = await RoomMember.getRoomMembers(roomId);

    res.json({
      room: {
        id: room._id,
        name: room.name,
        avatar: room.avatar,
        description: room.description,
        type: room.type,
        owner: room.ownerId,
        memberCount: room.memberCount,
        isPasswordProtected: room.isPasswordProtected,
        sessionKeyVersion: room.sessionKeyVersion,
        encryptedSessionKey: roomMember.encryptedSessionKey,
        settings: room.settings,
        createdAt: room.createdAt
      },
      members: members.map(m => ({
        id: m.userId._id,
        username: m.userId.username,
        email: m.userId.email,
        avatar: m.userId.avatar,
        role: m.role,
        joinedAt: m.joinedAt
      }))
    });

  } catch (error) {
    console.error('Get group error:', error);
    res.status(500).json({ error: 'Failed to get group details' });
  }
});

/**
 * @swagger
 * /api/groups:
 *   get:
 *     summary: Lấy danh sách groups của user
 *     description: Lấy tất cả groups mà user hiện tại là thành viên
 *     tags: [Groups]
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Số trang
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *         description: Số group mỗi trang
 *     responses:
 *       200:
 *         description: Danh sách groups
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 groups:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Room'
 *                 totalGroups:
 *                   type: integer
 *                 totalPages:
 *                   type: integer
 *                 currentPage:
 *                   type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */

/**
 * @swagger
 * /api/groups/{groupId}/join:
 *   post:
 *     summary: Tham gia group chat
 *     description: |
 *       Tham gia group chat. Nếu group có password thì cần cung cấp.
 *       Server sẽ trả về encrypted session key của user.
 *     tags: [Groups]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID của group
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               password:
 *                 type: string
 *                 description: Password của group (nếu có)
 *     responses:
 *       200:
 *         description: Tham gia thành công
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 room:
 *                   $ref: '#/components/schemas/Room'
 *                 encryptedSessionKey:
 *                   type: string
 *                   description: Session key đã mã hóa cho user
 *       400:
 *         description: Password sai hoặc đã là thành viên
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */

/**
 * @swagger
 * /api/groups/{groupId}/leave:
 *   post:
 *     summary: Rời group chat
 *     description: Rời khỏi group chat. Nếu là owner thì cần chuyển quyền owner trước.
 *     tags: [Groups]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID của group
 *     responses:
 *       200:
 *         description: Rời group thành công
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       400:
 *         description: Không thể rời - là owner duy nhất
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */

/**
 * @swagger
 * /api/groups/{groupId}/members:
 *   get:
 *     summary: Lấy danh sách thành viên
 *     description: Lấy danh sách tất cả thành viên trong group
 *     tags: [Groups]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID của group
 *     responses:
 *       200:
 *         description: Danh sách thành viên
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 members:
 *                   type: array
 *                   items:
 *                     allOf:
 *                       - $ref: '#/components/schemas/User'
 *                       - type: object
 *                         properties:
 *                           role:
 *                             type: string
 *                             enum: [owner, admin, member]
 *                           joinedAt:
 *                             type: string
 *                             format: date-time
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         description: Không phải thành viên group
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */

/**
 * @swagger
 * /api/groups/{groupId}/messages:
 *   get:
 *     summary: Lấy tin nhắn trong group
 *     description: Lấy lịch sử tin nhắn trong group chat
 *     tags: [Groups]
 *     parameters:
 *       - in: path
 *         name: groupId
 *         required: true
 *         schema:
 *           type: string
 *         description: ID của group
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *         description: Số tin nhắn mỗi trang
 *       - in: query
 *         name: skip
 *         schema:
 *           type: integer
 *           default: 0
 *         description: Số tin nhắn bỏ qua (pagination)
 *     responses:
 *       200:
 *         description: Danh sách tin nhắn
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 messages:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Message'
 *                 hasMore:
 *                   type: boolean
 *                   description: Còn tin nhắn cũ hơn không
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         description: Không phải thành viên group
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */

/**
 * POST /api/groups/:roomId/kick
 * Kick a member from group (Admin only)
 * IMPORTANT: Must trigger key rotation!
 * 
 * Request Body:
 * {
 *   memberIdToKick: "user_id",
 *   newEncryptedSessionKeys: [
 *     { userId: "remaining_user_1", encryptedKey: "new_encrypted_key" },
 *     { userId: "remaining_user_2", encryptedKey: "new_encrypted_key" }
 *   ]
 * }
 * 
 * Flow:
 * 1. Validate requester is admin
 * 2. Remove member from room
 * 3. Admin generates NEW SessionKey
 * 4. Admin encrypts new SessionKey for all REMAINING members
 * 5. Update all RoomMember entries with new encrypted keys
 * 6. Increment sessionKeyVersion
 * 7. Kicked member can't decrypt new messages (has old key)
 */
router.post('/:roomId/kick', auth, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { memberIdToKick, newEncryptedSessionKeys } = req.body;
    const adminId = req.userId;

    // Find room
    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Check if requester is owner
    if (!room.isOwner(adminId)) {
      return res.status(403).json({ error: 'Only group owner can kick members' });
    }

    // Can't kick yourself
    if (memberIdToKick === adminId) {
      return res.status(400).json({ error: 'You cannot kick yourself' });
    }

    // Check if target is member
    if (!room.isMember(memberIdToKick)) {
      return res.status(400).json({ error: 'User is not a member of this group' });
    }

    // Validate new encrypted keys provided
    if (!newEncryptedSessionKeys || !Array.isArray(newEncryptedSessionKeys)) {
      return res.status(400).json({ error: 'New encrypted session keys are required for key rotation' });
    }

    // Remove member from room
    await room.removeMember(memberIdToKick);

    // Deactivate kicked member's RoomMember entry
    await RoomMember.removeMember(roomId, memberIdToKick);

    // Rotate session key version
    await room.rotateSessionKey();
    const newKeyVersion = room.sessionKeyVersion;

    // Update all remaining members with new encrypted keys
    for (const { userId, encryptedKey } of newEncryptedSessionKeys) {
      const member = await RoomMember.getMemberKey(roomId, userId);
      if (member) {
        await member.updateSessionKey(encryptedKey, newKeyVersion);
      }
    }

    res.json({
      message: 'Member kicked successfully and session key rotated',
      room: {
        id: room._id,
        memberCount: room.memberCount,
        sessionKeyVersion: room.sessionKeyVersion
      },
      kickedUserId: memberIdToKick
    });

  } catch (error) {
    console.error('Kick member error:', error);
    res.status(500).json({ error: 'Failed to kick member' });
  }
});

/**
 * POST /api/groups/:roomId/add-member
 * Add a new member to group (Admin or members if allowed)
 * 
 * Request Body:
 * {
 *   userIdToAdd: "user_id",
 *   encryptedSessionKey: "encrypted_key_for_new_member"
 * }
 */
router.post('/:roomId/add-member', auth, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { userIdToAdd, encryptedSessionKey } = req.body;
    const requesterId = req.userId;

    // Find room
    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Check permissions
    const isOwner = room.isOwner(requesterId);
    const isMember = room.isMember(requesterId);
    
    if (!isOwner && (!isMember || !room.settings.allowMembersToAddMembers)) {
      return res.status(403).json({ error: 'You do not have permission to add members' });
    }

    // Check if user to add exists
    const userToAdd = await User.findById(userIdToAdd);
    if (!userToAdd) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check if already member
    if (room.isMember(userIdToAdd)) {
      return res.status(400).json({ error: 'User is already a member' });
    }

    // Check max members limit
    if (room.memberCount >= room.settings.maxMembers) {
      return res.status(400).json({ error: 'Group has reached maximum member limit' });
    }

    // Validate encrypted key
    if (!encryptedSessionKey) {
      return res.status(400).json({ error: 'Encrypted session key is required' });
    }

    // Add member to room
    await room.addMember(userIdToAdd);

    // Create RoomMember entry
    const roomMember = new RoomMember({
      roomId: room._id,
      userId: userIdToAdd,
      encryptedSessionKey,
      sessionKeyVersion: room.sessionKeyVersion,
      role: 'member'
    });

    await roomMember.save();

    res.json({
      message: 'Member added successfully',
      room: {
        id: room._id,
        memberCount: room.memberCount
      },
      newMember: {
        id: userToAdd._id,
        username: userToAdd.username,
        email: userToAdd.email,
        avatar: userToAdd.avatar
      }
    });

  } catch (error) {
    console.error('Add member error:', error);
    res.status(500).json({ error: 'Failed to add member' });
  }
});

/**
 * POST /api/groups/:roomId/leave
 * Leave a group (self-leave)
 */
router.post('/:roomId/leave', auth, async (req, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.userId;

    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Owner cannot leave (must transfer ownership first)
    if (room.isOwner(userId)) {
      return res.status(400).json({ error: 'Owner cannot leave. Transfer ownership first.' });
    }

    if (!room.isMember(userId)) {
      return res.status(400).json({ error: 'You are not a member of this group' });
    }

    // Remove member
    await room.removeMember(userId);
    await RoomMember.removeMember(roomId, userId);

    res.json({
      message: 'Left group successfully',
      roomId: room._id
    });

  } catch (error) {
    console.error('Leave group error:', error);
    res.status(500).json({ error: 'Failed to leave group' });
  }
});

/**
 * DELETE /api/groups/:roomId
 * Delete a group (owner only)
 */
router.delete('/:roomId', auth, async (req, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.userId;

    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({ error: 'Group not found' });
    }

    // Only owner can delete
    if (!room.isOwner(userId)) {
      return res.status(403).json({ error: 'Only the owner can delete this group' });
    }

    // Delete all room members
    await RoomMember.deleteMany({ roomId: room._id });

    // Delete all messages in the room
    const Message = require('../models/Message');
    await Message.deleteMany({ roomId: room._id });

    // Delete the room
    await Room.findByIdAndDelete(roomId);

    res.json({
      message: 'Group deleted successfully',
      roomId: room._id
    });

  } catch (error) {
    console.error('Delete group error:', error);
    res.status(500).json({ error: 'Failed to delete group' });
  }
});

module.exports = router;
