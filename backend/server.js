require('dotenv').config();
const express = require('express');
const cors = require('cors');
const swaggerUI = require('swagger-ui-express');
const swaggerSpecs = require('./config/swagger-simple');
const connectDB = require('./config/db');

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

// Middleware
app.use(cors({
  origin: '*', // Allow all origins in development
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: false
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect to MongoDB
connectDB();

// Export Swagger JSON
app.get('/api/docs/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', 'attachment; filename="swagger.json"');
  res.send(swaggerSpecs);
});

// Export Swagger YAML (optional)
app.get('/api/docs/swagger.yaml', (req, res) => {
  const yaml = require('js-yaml');
  res.setHeader('Content-Type', 'application/x-yaml');
  res.setHeader('Content-Disposition', 'attachment; filename="swagger.yaml"');
  try {
    const yamlStr = yaml.dump(swaggerSpecs);
    res.send(yamlStr);
  } catch (err) {
    res.status(500).json({ error: 'Failed to convert to YAML' });
  }
});

// Swagger Documentation
app.use('/api/docs', swaggerUI.serve, swaggerUI.setup(swaggerSpecs, {
  customCss: `
    .swagger-ui .topbar { display: none }
    .swagger-ui .info { margin: 20px 0; }
    .swagger-ui .info .title { color: #3b82f6; }
  `,
  customSiteTitle: 'E2EE Chat API Documentation',
  explorer: true,
  swaggerOptions: {
    urls: [
      {
        url: '/api/docs/swagger.json',
        name: 'E2EE Chat API'
      }
    ]
  }
}));

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
  res.json({ status: 'ok', message: 'Server đang hoạt động' });
});

// API root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Chào mừng đến với API Chat E2EE',
    version: '1.0.0',
    documentation: '/api/docs',
    swagger_json: '/api/docs/swagger.json',
    swagger_yaml: '/api/docs/swagger.yaml',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      users: '/api/users', 
      messages: '/api/messages',
      files: '/api/files',
      profile: '/api/profile',
      admin: '/api/admin',
      storage: '/api',
      groups: '/api/groups'
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════════╗
║  E2EE Chat Server                          ║
║  Port: ${PORT}                              ║
║  Environment: ${process.env.NODE_ENV || 'development'}              ║
║  Status: Ready                             ║
╚════════════════════════════════════════════╝
  `);
  console.log(`✓ Server listening on http://localhost:${PORT}`);
  console.log(`✓ API Health Check: http://localhost:${PORT}/health`);
}).on('error', (err) => {
  console.error('❌ Server failed to start:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`❌ Port ${PORT} is already in use`);
  }
  process.exit(1);
});

module.exports = { app };
