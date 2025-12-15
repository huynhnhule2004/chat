const Message = require('../models/Message');

class MessageService {
  constructor() {
    this.MESSAGE_LIMIT = parseInt(process.env.MESSAGE_LIMIT) || 1000;
  }

  // Save message and cleanup old ones
  async saveMessage(messageData) {
    try {
      // Create new message
      const newMessage = await Message.create(messageData);

      // Cleanup old messages for this conversation
      await this.cleanupOldMessages(messageData.sender, messageData.receiver);

      return newMessage;
    } catch (error) {
      console.error('Save message error:', error);
      throw error;
    }
  }

  // Clean up old messages when exceeding limit
  async cleanupOldMessages(userId1, userId2) {
    try {
      // Count messages in this conversation
      const count = await Message.countDocuments({
        $or: [
          { sender: userId1, receiver: userId2 },
          { sender: userId2, receiver: userId1 }
        ]
      });

      // If exceeds limit, delete oldest messages
      if (count > this.MESSAGE_LIMIT) {
        const excess = count - this.MESSAGE_LIMIT;
        
        // Find oldest messages
        const oldMessages = await Message.find({
          $or: [
            { sender: userId1, receiver: userId2 },
            { sender: userId2, receiver: userId1 }
          ]
        })
        .sort({ timestamp: 1 })
        .limit(excess)
        .select('_id');

        const idsToDelete = oldMessages.map(msg => msg._id);
        
        // Delete old messages
        await Message.deleteMany({ _id: { $in: idsToDelete } });
        
        console.log(`✓ Cleaned up ${excess} old messages`);
      }
    } catch (error) {
      console.error('Cleanup error:', error);
    }
  }

  // Get recent messages between two users
  async getMessages(userId1, userId2, limit = 50, skip = 0) {
    try {
      const messages = await Message.find({
        $or: [
          { sender: userId1, receiver: userId2 },
          { sender: userId2, receiver: userId1 }
        ]
      })
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit)
      .populate('sender', 'username')
      .populate('receiver', 'username');

      return messages.reverse(); // Oldest first
    } catch (error) {
      console.error('Get messages error:', error);
      throw error;
    }
  }

  // Get conversations list for a user
  async getConversations(userId) {
    try {
      const conversations = await Message.aggregate([
        {
          $match: {
            $or: [{ sender: userId }, { receiver: userId }]
          }
        },
        {
          $sort: { timestamp: -1 }
        },
        {
          $group: {
            _id: {
              $cond: [
                { $eq: ['$sender', userId] },
                '$receiver',
                '$sender'
              ]
            },
            lastMessage: { $first: '$$ROOT' }
          }
        },
        {
          $lookup: {
            from: 'users',
            localField: '_id',
            foreignField: '_id',
            as: 'otherUser'
          }
        },
        {
          $unwind: '$otherUser'
        },
        {
          $project: {
            userId: '$_id',
            username: '$otherUser.username',
            lastMessage: {
              content: '$lastMessage.content',
              timestamp: '$lastMessage.timestamp',
              messageType: '$lastMessage.messageType'
            }
          }
        },
        {
          $sort: { 'lastMessage.timestamp': -1 }
        }
      ]);

      return conversations;
    } catch (error) {
      console.error('Get conversations error:', error);
      throw error;
    }
  }
}

module.exports = new MessageService();
