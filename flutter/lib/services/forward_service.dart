import 'package:sqflite/sqflite.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../database/database_helper.dart';
import 'crypto_service.dart';

/// Service for handling message forwarding with E2EE re-encryption
class ForwardService {
  static final ForwardService instance = ForwardService._init();
  final CryptoService _cryptoService = CryptoService.instance;

  ForwardService._init();

  /// Forward a message to multiple recipients
  ///
  /// This implements the core E2EE forwarding logic:
  /// 1. Decrypt the original message using sender's shared key
  /// 2. For each recipient, re-encrypt with their shared key
  /// 3. Send as new messages to each recipient
  ///
  /// [originalMessage] - The message to forward
  /// [recipients] - List of users to forward to
  /// [currentUserId] - ID of user performing the forward
  /// [originalSenderUsername] - Username of original sender (for display)
  Future<List<Message>> forwardMessage({
    required Message originalMessage,
    required List<User> recipients,
    required String currentUserId,
    required String originalSenderUsername,
  }) async {
    final forwardedMessages = <Message>[];

    // Step 1: Decrypt the original message content
    final decryptedContent = await _decryptMessage(
      originalMessage.content,
      originalMessage.senderId == currentUserId
          ? originalMessage.receiverId
          : originalMessage.senderId,
    );

    if (decryptedContent == null) {
      throw Exception('Failed to decrypt original message');
    }

    // Step 2: For each recipient, re-encrypt and create new message
    for (final recipient in recipients) {
      // Re-encrypt content with recipient's shared key
      final reencryptedContent = await _encryptMessage(
        decryptedContent,
        recipient.id,
      );

      if (reencryptedContent == null) {
        print('Failed to encrypt message for recipient ${recipient.id}');
        continue;
      }

      // Handle file forwarding (Key Wrapping)
      String? reencryptedFileKey;
      if (originalMessage.fileUrl != null &&
          originalMessage.encryptedFileKey != null) {
        reencryptedFileKey = await _rewrapFileKey(
          originalMessage.encryptedFileKey!,
          originalMessage.senderId == currentUserId
              ? originalMessage.receiverId
              : originalMessage.senderId,
          recipient.id,
        );
      }

      // Create forwarded message
      final forwardedMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString() + recipient.id,
        senderId: currentUserId,
        receiverId: recipient.id,
        content: reencryptedContent,
        messageType: originalMessage.messageType,
        timestamp: DateTime.now(),
        isSent: false,
        isRead: false,
        isForwarded: true,
        originalSenderId: originalMessage.isForwarded
            ? originalMessage.originalSenderId
            : originalMessage.senderId,
        forwardedFrom: originalMessage.isForwarded
            ? originalMessage.forwardedFrom
            : originalSenderUsername,
        fileUrl: originalMessage.fileUrl,
        encryptedFileKey: reencryptedFileKey,
        fileSize: originalMessage.fileSize,
      );

      forwardedMessages.add(forwardedMessage);

      // Save to local database
      await _saveMessageToDatabase(forwardedMessage);
    }

    return forwardedMessages;
  }

  /// Decrypt message content using shared key with sender/receiver
  Future<String?> _decryptMessage(
    String encryptedContent,
    String otherUserId,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'encryption_keys',
        where: 'user_id = ?',
        whereArgs: [otherUserId],
      );

      if (results.isEmpty) {
        print('No shared key found for user $otherUserId');
        return null;
      }

      final sharedKeyHex = results.first['shared_key'] as String;

      // Decrypt using CryptoService
      return await _cryptoService.decryptMessage(
        encryptedContent,
        sharedKeyHex,
      );
    } catch (e) {
      print('Error decrypting message: $e');
      return null;
    }
  }

  /// Encrypt message content using shared key with recipient
  Future<String?> _encryptMessage(String plaintext, String recipientId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'encryption_keys',
        where: 'user_id = ?',
        whereArgs: [recipientId],
      );

      if (results.isEmpty) {
        print('No shared key found for recipient $recipientId');
        return null;
      }

      final sharedKeyHex = results.first['shared_key'] as String;

      // Encrypt using CryptoService
      return await _cryptoService.encryptMessage(plaintext, sharedKeyHex);
    } catch (e) {
      print('Error encrypting message: $e');
      return null;
    }
  }

  /// Re-wrap file encryption key for new recipient
  ///
  /// This implements the File Key Wrapping strategy:
  /// 1. Decrypt the file key using original recipient's shared secret
  /// 2. Re-encrypt the file key using new recipient's shared secret
  ///
  /// The actual file remains unchanged on the server!
  Future<String?> _rewrapFileKey(
    String encryptedFileKey,
    String originalOtherUserId,
    String newRecipientId,
  ) async {
    try {
      // Step 1: Decrypt file key with original shared secret
      final decryptedFileKey = await _decryptMessage(
        encryptedFileKey,
        originalOtherUserId,
      );

      if (decryptedFileKey == null) return null;

      // Step 2: Re-encrypt file key with new recipient's shared secret
      final reencryptedFileKey = await _encryptMessage(
        decryptedFileKey,
        newRecipientId,
      );

      return reencryptedFileKey;
    } catch (e) {
      print('Error rewrapping file key: $e');
      return null;
    }
  }

  /// Save forwarded message to local database
  Future<void> _saveMessageToDatabase(Message message) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'messages',
        message.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error saving message to database: $e');
    }
  }
}
