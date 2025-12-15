import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;

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
      version: 1,
      onCreate: _createDB,
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
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        message_type TEXT NOT NULL DEFAULT 'text',
        timestamp INTEGER NOT NULL,
        is_sent INTEGER NOT NULL DEFAULT 0,
        is_read INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (sender_id) REFERENCES users (id),
        FOREIGN KEY (receiver_id) REFERENCES users (id)
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
    return await db.rawQuery('''
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
    ''', [userId, userId, userId, userId, userId]);
  }

  Future<int> getUnreadCount(String userId, String senderId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM messages
      WHERE receiver_id = ? AND sender_id = ? AND is_read = 0
    ''', [userId, senderId]);
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

  // Encryption key operations
  Future<void> saveSharedKey(String userId, String sharedKey) async {
    final db = await database;
    await db.insert(
      'encryption_keys',
      {
        'user_id': userId,
        'shared_key': sharedKey,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}
