import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/storage_info.dart';
import '../database/database_helper.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Tính toán tổng dung lượng app sử dụng (chạy trên Isolate)
  Future<StorageInfo> analyzeStorage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = await getDatabasesPath();
      final fullDbPath = join(dbPath, 'e2ee_chat.db');

      // Tính device storage
      final statFs = appDir.statSync();
      final totalBytes = statFs.size * (await _getBlockCount(appDir.path));
      final freeBytes = statFs.size * (await _getFreeBlocks(appDir.path));

      // Phân tích storage của app trên Isolate để tránh block UI
      final params = StorageAnalysisParams(
        appDir: appDir.path,
        dbPath: fullDbPath,
      );

      final result = await compute(_analyzeAppStorageIsolate, params);

      return StorageInfo(
        totalBytes: totalBytes,
        freeBytes: freeBytes,
        usedByApp: result['totalSize'] as int,
        chatStorages: result['chatStorages'] as Map<String, ChatStorageInfo>,
      );
    } catch (e) {
      print('Error analyzing storage: $e');
      rethrow;
    }
  }

  /// Isolate worker function - chạy ngầm để tính storage
  static Future<Map<String, dynamic>> _analyzeAppStorageIsolate(
    StorageAnalysisParams params,
  ) async {
    final chatStorages = <String, ChatStorageInfo>{};
    int totalSize = 0;

    try {
      // 1. Tính dung lượng database
      final dbFile = File(params.dbPath);
      final dbSize = await dbFile.exists() ? await dbFile.length() : 0;
      totalSize += dbSize;

      // 2. Phân tích từng chat
      final db = await openDatabase(params.dbPath);

      // Lấy danh sách conversations
      final conversations = await db.query(
        'conversations',
        columns: ['user_id', 'username'],
      );

      for (final conv in conversations) {
        final userId = conv['user_id'] as String;
        final username = conv['username'] as String;

        // Đếm messages
        final messageCount =
            Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM messages WHERE receiver_id = ? OR sender_id = ?',
                [userId, userId],
              ),
            ) ??
            0;

        // Lấy danh sách files
        final messages = await db.query(
          'messages',
          columns: ['file_path', 'file_type', 'timestamp'],
          where: '(receiver_id = ? OR sender_id = ?) AND file_path IS NOT NULL',
          whereArgs: [userId, userId],
        );

        final files = <FileStorageInfo>[];
        int mediaSize = 0;
        int cacheSize = 0;

        for (final msg in messages) {
          final filePath = msg['file_path'] as String?;
          if (filePath == null) continue;

          final fullPath = '${params.appDir}/$filePath';
          final file = File(fullPath);

          if (await file.exists()) {
            final size = await file.length();
            final type = msg['file_type'] as String? ?? 'file';
            final timestamp = msg['timestamp'] as int;

            files.add(
              FileStorageInfo(
                path: filePath,
                type: type,
                size: size,
                uploadedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
              ),
            );

            // Phân loại cache vs media
            if (filePath.contains('/cache/') ||
                filePath.contains('/thumbnails/')) {
              cacheSize += size;
            } else {
              mediaSize += size;
            }

            totalSize += size;
          }
        }

        chatStorages[userId] = ChatStorageInfo(
          userId: userId,
          username: username,
          messageCount: messageCount,
          databaseSize: (dbSize / conversations.length).round(),
          mediaSize: mediaSize,
          cacheSize: cacheSize,
          files: files,
        );
      }

      await db.close();
    } catch (e) {
      print('Error in isolate analysis: $e');
    }

    return {'totalSize': totalSize, 'chatStorages': chatStorages};
  }

  /// Xóa cache (Level 1)
  Future<int> clearCache() async {
    int deletedSize = 0;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/cache');
      final thumbnailsDir = Directory('${appDir.path}/thumbnails');

      // Xóa cache
      if (await cacheDir.exists()) {
        deletedSize += await _deleteDirectory(cacheDir);
      }

      // Xóa thumbnails
      if (await thumbnailsDir.exists()) {
        deletedSize += await _deleteDirectory(thumbnailsDir);
      }

      // Tạo lại thư mục
      await cacheDir.create(recursive: true);
      await thumbnailsDir.create(recursive: true);
    } catch (e) {
      print('Error clearing cache: $e');
    }

    return deletedSize;
  }

  /// Xóa lịch sử chat cụ thể (Level 2)
  Future<int> deleteChatHistory(String userId) async {
    int deletedSize = 0;

    try {
      final db = await DatabaseHelper.instance.database;
      final appDir = await getApplicationDocumentsDirectory();

      // Lấy danh sách files trước khi xóa
      final messages = await db.query(
        'messages',
        columns: ['file_path'],
        where: 'receiver_id = ? OR sender_id = ?',
        whereArgs: [userId, userId],
      );

      // Xóa files
      for (final msg in messages) {
        final filePath = msg['file_path'] as String?;
        if (filePath != null) {
          final file = File('${appDir.path}/$filePath');
          if (await file.exists()) {
            deletedSize += await file.length();
            await file.delete();
          }
        }
      }

      // Xóa messages trong database
      await db.delete(
        'messages',
        where: 'receiver_id = ? OR sender_id = ?',
        whereArgs: [userId, userId],
      );

      // Xóa conversation
      await db.delete(
        'conversations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error deleting chat history: $e');
    }

    return deletedSize;
  }

  /// Xóa tin nhắn cũ theo thời gian (Level 3)
  Future<int> deleteOldMessages(Duration age) async {
    int deletedSize = 0;

    try {
      final db = await DatabaseHelper.instance.database;
      final appDir = await getApplicationDocumentsDirectory();
      final cutoffTime = DateTime.now().subtract(age).millisecondsSinceEpoch;

      // Lấy messages cũ
      final messages = await db.query(
        'messages',
        columns: ['id', 'file_path'],
        where: 'timestamp < ?',
        whereArgs: [cutoffTime],
      );

      // Xóa files
      for (final msg in messages) {
        final filePath = msg['file_path'] as String?;
        if (filePath != null) {
          final file = File('${appDir.path}/$filePath');
          if (await file.exists()) {
            deletedSize += await file.length();
            await file.delete();
          }
        }
      }

      // Xóa records
      await db.delete(
        'messages',
        where: 'timestamp < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      print('Error deleting old messages: $e');
    }

    return deletedSize;
  }

  /// Helper: Xóa thư mục và tính tổng size
  Future<int> _deleteDirectory(Directory dir) async {
    int totalSize = 0;

    try {
      final files = dir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
          await file.delete();
        }
      }
    } catch (e) {
      print('Error deleting directory: $e');
    }

    return totalSize;
  }

  /// Platform-specific: Lấy block count
  Future<int> _getBlockCount(String path) async {
    // Simplified - trong production cần dùng platform channel
    return 1000000; // Mock value
  }

  /// Platform-specific: Lấy free blocks
  Future<int> _getFreeBlocks(String path) async {
    // Simplified - trong production cần dùng platform channel
    return 500000; // Mock value
  }
}
