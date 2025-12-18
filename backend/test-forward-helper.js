#!/usr/bin/env node

/**
 * Test Helper Script for Forward Message Feature
 * Usage: node test-forward-helper.js
 */

const axios = require('axios');

const API_BASE = 'http://localhost:3000';

// Test users
const testUsers = [
  { username: 'test_a', email: 'test_a@test.com', password: 'password123' },
  { username: 'test_b', email: 'test_b@test.com', password: 'password123' },
  { username: 'test_c', email: 'test_c@test.com', password: 'password123' },
  { username: 'test_d', email: 'test_d@test.com', password: 'password123' },
  { username: 'test_e', email: 'test_e@test.com', password: 'password123' },
];

async function createTestUsers() {
  console.log('🔧 Creating test users...\n');
  
  for (const user of testUsers) {
    try {
      const response = await axios.post(`${API_BASE}/api/auth/register`, user);
      console.log(`✅ Created: ${user.username} (ID: ${response.data.userId})`);
    } catch (error) {
      if (error.response?.status === 400) {
        console.log(`⚠️  Already exists: ${user.username}`);
      } else {
        console.error(`❌ Error creating ${user.username}:`, error.message);
      }
    }
  }
}

async function loginUser(email, password) {
  try {
    const response = await axios.post(`${API_BASE}/api/auth/login`, {
      email,
      password,
    });
    return response.data;
  } catch (error) {
    console.error(`❌ Login failed for ${email}:`, error.message);
    return null;
  }
}

async function checkForwardMessages() {
  console.log('\n\n📊 Checking forwarded messages in database...\n');
  
  // This requires direct DB access or API endpoint
  console.log('To check database:');
  console.log('1. Connect to MongoDB:');
  console.log('   mongosh "mongodb://localhost:27017/e2ee_chat"');
  console.log('');
  console.log('2. Query forwarded messages:');
  console.log('   db.messages.find({ isForwarded: true }).pretty()');
  console.log('');
  console.log('3. Check file key wrapping:');
  console.log('   db.messages.find({ encryptedFileKey: { $exists: true } }).pretty()');
}

async function printTestInstructions() {
  console.log('\n\n📋 TEST INSTRUCTIONS\n');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  console.log('Step 1: Login with test accounts in Flutter app');
  console.log('  - test_a@test.com / password123');
  console.log('  - test_b@test.com / password123');
  console.log('  - test_c@test.com / password123\n');
  
  console.log('Step 2: Send test message');
  console.log('  - User B sends "Hello Forward Test!" to User A\n');
  
  console.log('Step 3: Test forward flow');
  console.log('  - User A: Long-press message');
  console.log('  - Tap "Forward"');
  console.log('  - Select User C');
  console.log('  - Confirm forward\n');
  
  console.log('Step 4: Verify results');
  console.log('  ✅ User C receives message');
  console.log('  ✅ Badge shows "Forwarded from test_b"');
  console.log('  ✅ Content matches original');
  console.log('  ✅ Message encrypted with User C\'s key\n');
  
  console.log('Step 5: Test multi-forward');
  console.log('  - User A: Forward same message');
  console.log('  - Select User C, D, E (3 users)');
  console.log('  - Verify all 3 receive forwarded message\n');
  
  console.log('═══════════════════════════════════════════════════════════\n');
}

async function printPerformanceTests() {
  console.log('\n\n⚡ PERFORMANCE TESTS\n');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  console.log('Test 1: Forward Text Message');
  console.log('  Expected time: < 100ms');
  console.log('  Expected network: < 1KB\n');
  
  console.log('Test 2: Forward to 10 Users');
  console.log('  Expected time: < 1 second');
  console.log('  Expected network: < 10KB\n');
  
  console.log('Test 3: Forward Image (5MB)');
  console.log('  Expected time: < 200ms');
  console.log('  Expected network: < 1KB (file key wrapping!)');
  console.log('  ⚠️  Should NOT re-upload 5MB\n');
  
  console.log('Test 4: Forward Video (100MB) to 20 Users');
  console.log('  Expected time: < 2 seconds');
  console.log('  Expected network: < 10KB (20 × file keys)');
  console.log('  💰 Bandwidth savings: 99.99%\n');
  
  console.log('═══════════════════════════════════════════════════════════\n');
}

async function printSecurityChecks() {
  console.log('\n\n🔒 SECURITY VERIFICATION\n');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  console.log('Check 1: Unique Encryption per Recipient');
  console.log('  - Forward same message to User C and User D');
  console.log('  - Check database: content should be DIFFERENT');
  console.log('  - Each encrypted with different shared key\n');
  
  console.log('Check 2: File Key Wrapping');
  console.log('  - Forward image to multiple users');
  console.log('  - fileUrl should be SAME (no re-upload)');
  console.log('  - encryptedFileKey should be DIFFERENT per user\n');
  
  console.log('Check 3: Original Sender Preservation');
  console.log('  - Chain forward: B→A→C→D');
  console.log('  - User D should see "Forwarded from test_b"');
  console.log('  - NOT "Forwarded from test_c"\n');
  
  console.log('Check 4: No Plaintext Leakage');
  console.log('  - Monitor network traffic (DevTools)');
  console.log('  - Should NEVER see plaintext content');
  console.log('  - All socket.emit() should contain encrypted data\n');
  
  console.log('═══════════════════════════════════════════════════════════\n');
}

async function main() {
  console.log('\n');
  console.log('╔═══════════════════════════════════════════════════════╗');
  console.log('║  Forward Message Feature - Test Helper Script        ║');
  console.log('╚═══════════════════════════════════════════════════════╝');
  console.log('\n');

  // Create test users
  await createTestUsers();

  // Print test instructions
  await printTestInstructions();

  // Print performance tests
  await printPerformanceTests();

  // Print security checks
  await printSecurityChecks();

  // Check forwarded messages
  await checkForwardMessages();

  console.log('\n✅ Test helper setup complete!\n');
  console.log('📱 Now open Flutter app and start testing...\n');
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { createTestUsers, loginUser };
