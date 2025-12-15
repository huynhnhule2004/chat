const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const User = require('../models/User');

// Get user's public key
router.get('/:userId/public-key', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('publicKey username');
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      userId: user._id,
      username: user.username,
      publicKey: user.publicKey
    });
  } catch (error) {
    console.error('Get public key error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Search users
router.get('/search', authMiddleware, async (req, res) => {
  try {
    const { query } = req.query;
    
    const users = await User.find({
      username: { $regex: query, $options: 'i' },
      _id: { $ne: req.userId } // Exclude current user
    }).select('username publicKey').limit(20);

    res.json({ users });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
