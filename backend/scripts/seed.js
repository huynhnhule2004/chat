/* eslint-disable no-console */
/**
 * Seed script (idempotent) to create sample users, a demo group room,
 * and ensure indexes are present for core collections.
 *
 * Usage:
 *   MONGODB_URI=... node scripts/seed.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const crypto = require('crypto');

const User = require('../models/User');
const Room = require('../models/Room');
const RoomMember = require('../models/RoomMember');
const Message = require('../models/Message');

const MONGODB_URI = process.env.MONGODB_URI;
if (!MONGODB_URI) {
  console.error('✗ Missing MONGODB_URI. Please set it in backend/.env');
  process.exit(1);
}

function randomBase64(bytes = 32) {
  return crypto.randomBytes(bytes).toString('base64');
}

async function ensureIndexes() {
  await Promise.all([
    User.createIndexes(),
    Room.createIndexes(),
    RoomMember.createIndexes(),
    Message.createIndexes(),
  ]);
  console.log('✓ Indexes ensured for users/rooms/roomMembers/messages');
}

async function ensureUser(username, email, password) {
  let user = await User.findOne({ username });
  if (user) {
    console.log(`ℹ️  User "${username}" already exists (${user._id})`);
    return user;
  }

  user = new User({
    username,
    email,
    password,
    publicKey: `test-public-key-${randomBase64(8)}`, // placeholder ECDH key
    role: username === 'admin' ? 'admin' : 'user',
  });
  await user.save();
  console.log(`✓ Created user "${username}" (${user._id})`);
  return user;
}

async function ensureDirectMessage(senderId, receiverId) {
  const existing = await Message.findOne({
    sender: senderId,
    receiver: receiverId,
    roomId: null,
  });
  if (existing) {
    console.log('ℹ️  Direct message already exists');
    return;
  }

  const message = new Message({
    sender: senderId,
    receiver: receiverId,
    content: 'Hello from seed script (unencrypted demo message)',
    messageType: 'text',
    timestamp: new Date(),
  });
  await message.save();
  console.log('✓ Added sample direct message');
}

async function ensureGroup(admin, member) {
  let room = await Room.findOne({ name: 'Demo Group' });
  if (!room) {
    room = new Room({
      name: 'Demo Group',
      description: 'Sample seeded group for testing',
      ownerId: admin._id,
      members: [admin._id, member._id],
      memberCount: 2,
      isPasswordProtected: false,
      sessionKeyVersion: 1,
    });
    await room.save();
    console.log(`✓ Created demo group (${room._id})`);
  } else {
    console.log(`ℹ️  Demo group already exists (${room._id})`);
  }

  // Ensure room member entries with placeholder encrypted keys
  const members = [
    { user: admin, role: 'owner' },
    { user: member, role: 'member' },
  ];

  for (const { user, role } of members) {
    let rm = await RoomMember.findOne({ roomId: room._id, userId: user._id });
    if (!rm) {
      rm = new RoomMember({
        roomId: room._id,
        userId: user._id,
        encryptedSessionKey: randomBase64(32), // placeholder; clients should replace
        sessionKeyVersion: room.sessionKeyVersion,
        role,
      });
      await rm.save();
      console.log(`✓ Added RoomMember for ${user.username} (${role})`);
    } else {
      console.log(`ℹ️  RoomMember already exists for ${user.username}`);
    }
  }

  // Seed a group message if none exists
  const existingGroupMsg = await Message.findOne({ roomId: room._id });
  if (!existingGroupMsg) {
    const msg = new Message({
      sender: admin._id,
      roomId: room._id,
      receiver: null,
      content: 'Welcome to the demo group (unencrypted seed message)',
      messageType: 'text',
      timestamp: new Date(),
    });
    await msg.save();
    console.log('✓ Added sample group message');
  } else {
    console.log('ℹ️  Group already has messages');
  }

  return room;
}

async function main() {
  console.log('⏳ Connecting to MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('✓ MongoDB connected');

  await ensureIndexes();

  const admin = await ensureUser('admin', 'admin@example.com', 'Admin123!');
  const demo = await ensureUser('demo', 'demo@example.com', 'Demo123!');
  const extraUsers = [
    { username: 'alice', email: 'alice@example.com', password: 'Alice123!' },
    { username: 'bob', email: 'bob@example.com', password: 'Bob123!' },
    { username: 'charlie', email: 'charlie@example.com', password: 'Charlie123!' },
    { username: 'diana', email: 'diana@example.com', password: 'Diana123!' },
    { username: 'eve', email: 'eve@example.com', password: 'Eve123!' }
  ];

  for (const u of extraUsers) {
    await ensureUser(u.username, u.email, u.password);
  }

  await ensureDirectMessage(admin._id, demo._id);
  await ensureGroup(admin, demo);

  const userCount = await User.countDocuments();
  const roomCount = await Room.countDocuments();
  const messageCount = await Message.countDocuments();

  console.log('✅ Seed complete');
  console.log(`Users: ${userCount} | Rooms: ${roomCount} | Messages: ${messageCount}`);

  await mongoose.disconnect();
  process.exit(0);
}

main().catch(async (err) => {
  console.error('✗ Seed failed:', err);
  await mongoose.disconnect();
  process.exit(1);
});
