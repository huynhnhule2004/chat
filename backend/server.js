require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const connectDB = require('./config/db');
const SocketService = require('./services/socketService');

// Import routes
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const messagesRoutes = require('./routes/messages');
const filesRoutes = require('./routes/files');
const profileRoutes = require('./routes/profile');
const adminRoutes = require('./routes/admin');
const storageRoutes = require('./routes/storage');
const groupsRoutes = require('./routes/groups'); // Group chat routes

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Initialize Socket.io with CORS
const io = socketIo(server, {
  cors: {
    origin: '*', // Change this in production
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect to MongoDB
connectDB();

// Initialize Socket Service
new SocketService(io);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/messages', messagesRoutes);
app.use('/api/files', filesRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api', storageRoutes);
app.use('/api/groups', groupsRoutes); // Group chat endpoints

// Serve uploaded files (avatars, files, etc.)
app.use('/uploads', express.static('uploads'));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════════╗
║  E2EE Chat Server                          ║
║  Port: ${PORT}                              ║
║  Environment: ${process.env.NODE_ENV || 'development'}              ║
║  Socket.IO: Ready                          ║
╚════════════════════════════════════════════╝
  `);
  console.log(`✓ Server listening on http://localhost:${PORT}`);
  console.log(`✓ Socket.IO endpoint: http://localhost:${PORT}/socket.io/`);
}).on('error', (err) => {
  console.error('❌ Server failed to start:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ Port ${PORT} is already in use`);
  }
  process.exit(1);
});

module.exports = { app, server, io };
