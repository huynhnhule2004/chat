import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('e2ee_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // v3: Add group chat support (rooms + room_members)
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        public_key TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT,
        room_id TEXT,
        content TEXT NOT NULL,
        message_type TEXT NOT NULL DEFAULT 'text',
        timestamp INTEGER NOT NULL,
        is_sent INTEGER NOT NULL DEFAULT 0,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_forwarded INTEGER NOT NULL DEFAULT 0,
        original_sender_id TEXT,
        forwarded_from TEXT,
        file_url TEXT,
        encrypted_file_key TEXT,
        file_size INTEGER,
        iv TEXT,
        auth_tag TEXT,
        FOREIGN KEY (sender_id) REFERENCES users (id),
        FOREIGN KEY (receiver_id) REFERENCES users (id),
        FOREIGN KEY (room_id) REFERENCES rooms (id)
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_messages_conversation 
      ON messages (sender_id, receiver_id, timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_timestamp 
      ON messages (timestamp DESC)
    ''');

    // Encryption keys table (for storing shared keys)
    await db.execute('''
      CREATE TABLE encryption_keys (
        user_id TEXT PRIMARY KEY,
        shared_key TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Rooms table (group chats)
    await db.execute('''
      CREATE TABLE rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar TEXT,
        description TEXT,
        type TEXT NOT NULL DEFAULT 'group',
        owner_id TEXT NOT NULL,
        is_password_protected INTEGER NOT NULL DEFAULT 0,
        member_count INTEGER NOT NULL DEFAULT 0,
        session_key_version INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        last_message_at TEXT,
        FOREIGN KEY (owner_id) REFERENCES users (id)
      )
    ''');

    // Room members table (stores encrypted session keys)
    await db.execute('''
      CREATE TABLE room_members (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        encrypted_session_key TEXT NOT NULL,
        session_key_version INTEGER NOT NULL DEFAULT 1,
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        is_muted INTEGER NOT NULL DEFAULT 0,
        muted_until TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (room_id) REFERENCES rooms (id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        UNIQUE(room_id, user_id)
      )
    ''');

    // Create indexes for group chat
    await db.execute('''
      CREATE INDEX idx_rooms_owner ON rooms (owner_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_room_members_room ON room_members (room_id, is_active)
    ''');

    await db.execute('''
      CREATE INDEX idx_room_members_user ON room_members (user_id, is_active)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_room ON messages (room_id, timestamp DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Upgrade from v1 to v2: Add forward message fields
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE messages ADD COLUMN is_forwarded INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE messages ADD COLUMN original_sender_id TEXT',
      );
      await db.execute('ALTER TABLE messages ADD COLUMN forwarded_from TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN file_url TEXT');
      await db.execute(
        'ALTER TABLE messages ADD COLUMN encrypted_file_key TEXT',
      );
      await db.execute('ALTER TABLE messages ADD COLUMN file_size INTEGER');
    }

    // Upgrade from v2 to v3: Add group chat support
    if (oldVersion < 3) {
      // Add group fields to messages table
      await db.execute('ALTER TABLE messages ADD COLUMN room_id TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN iv TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN auth_tag TEXT');

      // Create rooms table
      await db.execute('''
        CREATE TABLE rooms (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          avatar TEXT,
          description TEXT,
          type TEXT NOT NULL DEFAULT 'group',
          owner_id TEXT NOT NULL,
          is_password_protected INTEGER NOT NULL DEFAULT 0,
          member_count INTEGER NOT NULL DEFAULT 0,
          session_key_version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          last_message_at TEXT,
          FOREIGN KEY (owner_id) REFERENCES users (id)
        )
      ''');

      // Create room_members table
      await db.execute('''
        CREATE TABLE room_members (
          id TEXT PRIMARY KEY,
          room_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          encrypted_session_key TEXT NOT NULL,
          session_key_version INTEGER NOT NULL DEFAULT 1,
          role TEXT NOT NULL DEFAULT 'member',
          joined_at TEXT NOT NULL,
          unread_count INTEGER NOT NULL DEFAULT 0,
          is_muted INTEGER NOT NULL DEFAULT 0,
          muted_until TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (room_id) REFERENCES rooms (id),
          FOREIGN KEY (user_id) REFERENCES users (id),
          UNIQUE(room_id, user_id)
        )
      ''');

      // Create indexes for group chat
      await db.execute(
          'CREATE INDEX idx_rooms_owner ON rooms (owner_id)');
      await db.execute(
          'CREATE INDEX idx_room_members_room ON room_members (room_id, is_active)');
      await db.execute(
          'CREATE INDEX idx_room_members_user ON room_members (user_id, is_active)');
      await db.execute(
          'CREATE INDEX idx_messages_room ON messages (room_id, timestamp DESC)');
    }
  }

  // User operations
  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert(
      'users',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Message operations
  Future<void> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String userId1,
    String userId2, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    return await db.query(
      'messages',
      where: '''
        (sender_id = ? AND receiver_id = ?) OR 
        (sender_id = ? AND receiver_id = ?)
      ''',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final db = await database;

    // Get last message for each conversation
    return await db.rawQuery(
      '''
      SELECT 
        u.id as user_id,
        u.username,
        m.content as last_message,
        m.timestamp as last_timestamp,
        m.message_type
      FROM (
        SELECT 
          CASE 
            WHEN sender_id = ? THEN receiver_id 
            ELSE sender_id 
          END as other_user_id,
          MAX(timestamp) as max_timestamp
        FROM messages
        WHERE sender_id = ? OR receiver_id = ?
        GROUP BY other_user_id
      ) conv
      JOIN messages m ON (
        ((m.sender_id = ? AND m.receiver_id = conv.other_user_id) OR
         (m.sender_id = conv.other_user_id AND m.receiver_id = ?)) AND
        m.timestamp = conv.max_timestamp
      )
      JOIN users u ON u.id = conv.other_user_id
      ORDER BY m.timestamp DESC
    ''',
      [userId, userId, userId, userId, userId],
    );
  }

  Future<int> getUnreadCount(String userId, String senderId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM messages
      WHERE receiver_id = ? AND sender_id = ? AND is_read = 0
    ''',
      [userId, senderId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markMessagesAsRead(String userId, String senderId) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'receiver_id = ? AND sender_id = ?',
      whereArgs: [userId, senderId],
    );
  }

  Future<void> updateMessageStatus(String messageId, bool isSent) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_sent': isSent ? 1 : 0},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // Encryption key operations
  Future<void> saveSharedKey(String userId, String sharedKey) async {
    final db = await database;
    await db.insert('encryption_keys', {
      'user_id': userId,
      'shared_key': sharedKey,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSharedKey(String userId) async {
    final db = await database;
    final results = await db.query(
      'encryption_keys',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first['shared_key'] as String : null;
  }

  // Clear all data
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('users');
    await db.delete('encryption_keys');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
  // ============================================================
  // GROUP CHAT DATABASE OPERATIONS
  // ============================================================

  // Room operations
  Future<void> insertRoom(Map<String, dynamic> room) async {
    final db = await database;
    
    await db.insert(
      'rooms',
      room,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    final db = await database;
    final results = await db.query(
      'rooms',
      where: 'id = ?',
      whereArgs: [roomId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUserRooms(String userId) async {
    final db = await database;
    // Join rooms with room_members to get user's rooms
    final results = await db.rawQuery('''
      SELECT r.* FROM rooms r
      INNER JOIN room_members rm ON r.id = rm.room_id
      WHERE rm.user_id = ? AND rm.is_active = 1
      ORDER BY r.last_message_at DESC
    ''', [userId]);
    return results;
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'rooms',
      data,
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  Future<void> deleteRoom(String roomId) async {
    final db = await database;
    await db.delete(
      'rooms',
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  // RoomMember operations
  Future<void> insertRoomMember(Map<String, dynamic> member) async {
    final db = await database;
    await db.insert(
      'room_members',
      member,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getRoomMember(
      String roomId, String userId) async {
    final db = await database;
    final results = await db.query(
      'room_members',
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    final db = await database;
    final results = await db.query(
      'room_members',
      where: 'room_id = ? AND is_active = 1',
      whereArgs: [roomId],
    );
    return results;
  }

  Future<void> updateRoomMember(
      String roomId, String userId, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'room_members',
      data,
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
  }

  Future<void> deactivateRoomMember(String roomId, String userId) async {
    final db = await database;
    await db.update(
      'room_members',
      {'is_active': 0},
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
  }

  // Get room messages
  Future<List<Map<String, dynamic>>> getRoomMessages(String roomId,
      {int limit = 50, int offset = 0}) async {
    final db = await database;
    final results = await db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return results.reversed.toList(); // Return in chronological order
  }}
