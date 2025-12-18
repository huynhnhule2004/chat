const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Message = require('../models/Message');
const fs = require('fs').promises;
const path = require('path');

// GET /api/storage-quota
// Lấy thông tin dung lượng file của user trên server
router.get('/storage-quota', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    // Tính tổng dung lượng files của user trên server
    const messages = await Message.find({
      $or: [
        { sender: userId },
        { receiver: userId }
      ],
      fileUrl: { $exists: true, $ne: null }
    });

    let totalSize = 0;
    const fileDetails = [];

    for (const message of messages) {
      if (message.fileUrl) {
        try {
          // Extract filename from URL
          const filename = path.basename(message.fileUrl);
          const filePath = path.join(__dirname, '../uploads', filename);

          // Check if file exists and get size
          const stats = await fs.stat(filePath);
          totalSize += stats.size;

          fileDetails.push({
            messageId: message._id,
            fileName: filename,
            fileType: message.fileType || 'unknown',
            size: stats.size,
            uploadedAt: message.timestamp
          });
        } catch (err) {
          // File không tồn tại hoặc lỗi, bỏ qua
          console.log(`File not found: ${message.fileUrl}`);
        }
      }
    }

    // Tính storage stats
    const uploadsDir = path.join(__dirname, '../uploads');
    let serverTotalSize = 0;
    
    try {
      const files = await fs.readdir(uploadsDir);
      for (const file of files) {
        const filePath = path.join(uploadsDir, file);
        const stats = await fs.stat(filePath);
        if (stats.isFile()) {
          serverTotalSize += stats.size;
        }
      }
    } catch (err) {
      console.error('Error reading uploads directory:', err);
    }

    res.json({
      userStorage: {
        totalSize,
        totalFiles: fileDetails.length,
        files: fileDetails,
        formattedSize: formatBytes(totalSize)
      },
      serverStorage: {
        totalSize: serverTotalSize,
        formattedSize: formatBytes(serverTotalSize)
      },
      quota: {
        limit: 100 * 1024 * 1024, // 100MB per user (example)
        used: totalSize,
        remaining: Math.max(0, (100 * 1024 * 1024) - totalSize),
        percentage: Math.min(100, (totalSize / (100 * 1024 * 1024)) * 100)
      }
    });

  } catch (error) {
    console.error('Storage quota error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/storage/cleanup
// Xóa files cũ của user (older than X days)
router.delete('/storage/cleanup', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const { olderThanDays = 90 } = req.body;

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - olderThanDays);

    // Tìm messages có file cũ
    const messages = await Message.find({
      $or: [
        { sender: userId },
        { receiver: userId }
      ],
      fileUrl: { $exists: true, $ne: null },
      timestamp: { $lt: cutoffDate }
    });

    let deletedSize = 0;
    let deletedCount = 0;

    for (const message of messages) {
      if (message.fileUrl) {
        try {
          const filename = path.basename(message.fileUrl);
          const filePath = path.join(__dirname, '../uploads', filename);

          const stats = await fs.stat(filePath);
          await fs.unlink(filePath);
          
          deletedSize += stats.size;
          deletedCount++;

          // Update message to remove file reference
          message.fileUrl = null;
          message.fileType = null;
          await message.save();
        } catch (err) {
          console.log(`Could not delete file: ${message.fileUrl}`);
        }
      }
    }

    res.json({
      success: true,
      deletedCount,
      deletedSize,
      formattedSize: formatBytes(deletedSize)
    });

  } catch (error) {
    console.error('Storage cleanup error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Helper function to format bytes
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

module.exports = router;
