const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const messageService = require('../services/messageService');

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

module.exports = router;
