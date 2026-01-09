/* eslint-disable no-console */
/**
 * Simple API smoke tests for health, auth, and file upload endpoints.
 * Requires backend/.env with MONGODB_URI and seeded users (admin/Admin123!).
 *
 * Run: npm run test:api
 */
const path = require('path');
const fs = require('fs');
const request = require('supertest');
const mongoose = require('mongoose');
require('dotenv').config({ path: path.join(__dirname, '.env') });

// Start server (server.js listens on require)
const { server } = require('./server');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  try {
    // Allow server to finish boot
    await sleep(500);

    const port = process.env.PORT || 3000;
    const baseUrl = `http://localhost:${port}`;
    console.log(`🌐 Using base URL: ${baseUrl}`);
    const agent = request(baseUrl);

    // Health check
    console.log('🔎 Checking /health ...');
    const health = await agent.get('/health');
    if (health.status !== 200 || health.body?.status !== 'ok') {
      throw new Error('Health check failed');
    }
    console.log('✅ Health OK');

    // Login
    console.log('🔑 Logging in as admin ...');
    const loginRes = await agent
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'Admin123!' });

    if (loginRes.status !== 200 || !loginRes.body?.token) {
      throw new Error(`Login failed: ${loginRes.status} ${JSON.stringify(loginRes.body)}`);
    }
    const token = loginRes.body.token;
    console.log('✅ Login OK, token acquired');

    const authHeader = { Authorization: `Bearer ${token}` };

    // Get groups
    console.log('👥 Fetching my groups ...');
    const groupsRes = await agent
      .get('/api/groups')
      .set(authHeader);

    if (groupsRes.status !== 200 || !Array.isArray(groupsRes.body?.rooms)) {
      throw new Error(`Get groups failed: ${groupsRes.status} ${JSON.stringify(groupsRes.body)}`);
    }
    const rooms = groupsRes.body.rooms;
    if (!rooms.length) {
      throw new Error('No groups returned for user');
    }
    const roomId = rooms[0].id;
    console.log(`✅ Got ${rooms.length} group(s); using room ${roomId}`);

    console.log('💬 Fetching group messages ...');
    const msgsRes = await agent
      .get(`/api/groups/${roomId}/messages`)
      .set(authHeader);

    if (msgsRes.status !== 200 || !Array.isArray(msgsRes.body?.messages)) {
      throw new Error(`Get group messages failed: ${msgsRes.status} ${JSON.stringify(msgsRes.body)}`);
    }
    console.log(`✅ Group messages fetched (${msgsRes.body.messages.length})`);

    // Upload text file
    console.log('📄 Uploading sample text file ...');
    const txtRes = await agent
      .post('/api/files/upload')
      .set(authHeader)
      .attach('file', Buffer.from('sample document from test-api'), 'sample.txt');

    if (txtRes.status !== 200 || !txtRes.body?.fileUrl) {
      throw new Error(`Text upload failed: ${txtRes.status} ${JSON.stringify(txtRes.body)}`);
    }
    console.log(`✅ Text upload OK: ${txtRes.body.fileUrl}`);

    // Upload tiny PNG (1x1)
    console.log('🖼️ Uploading sample image ...');
    const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQImWNgYGAAAAAEAAHIok8EAAAAAElFTkSuQmCC';
    const imgBuffer = Buffer.from(pngBase64, 'base64');

    const imgRes = await agent
      .post('/api/files/upload')
      .set(authHeader)
      .attach('file', imgBuffer, 'pixel.png');

    if (imgRes.status !== 200 || !imgRes.body?.fileUrl) {
      throw new Error(`Image upload failed: ${imgRes.status} ${JSON.stringify(imgRes.body)}`);
    }
    console.log(`✅ Image upload OK: ${imgRes.body.fileUrl}`);

    console.log('🎉 All API smoke tests passed');
  } catch (err) {
    console.error('❌ API tests failed:', err.message || err);
    process.exitCode = 1;
  } finally {
    // Close server to exit cleanly
    await new Promise((resolve) => {
      server.close(() => resolve());
      // Fallback: force exit after 2s
      setTimeout(resolve, 2000);
    });
    await mongoose.disconnect();
    process.exit();
  }
}

run();
