import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/crypto_service.dart';
import '../database/database_helper.dart';
import '../utils/key_migration_helper.dart';

class ChatProvider with ChangeNotifier {
  User? _currentUser;
  String? _token;
  List<Conversation> _conversations = [];
  Map<String, List<Message>> _messagesByUser = {};
  Map<String, String> _sharedKeys = {}; // userId -> sharedKey
  Map<String, bool> _typingStatus = {};

  User? get currentUser => _currentUser;
  String? get token => _token;
  List<Conversation> get conversations => _conversations;

  List<Message> getMessages(String userId) => _messagesByUser[userId] ?? [];
  bool isUserTyping(String userId) => _typingStatus[userId] ?? false;

  final ApiService _apiService = ApiService.instance;
  final SocketService _socketService = SocketService.instance;
  final CryptoService _cryptoService = CryptoService.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  ChatProvider() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // Handle incoming messages
    _socketService.onMessageReceived = (data) async {
      try {
        final message = Message.fromJson(data);

        // Skip if this is our own message (already added when sending)
        if (message.senderId == _currentUser?.id) {
          // Just update the message status to sent`1 ,
          await _db.updateMessageStatus(message.id, true);
          
          // Update in memory
          final receiverId = message.receiverId;
          if (_messagesByUser.containsKey(receiverId)) {
            final index = _messagesByUser[receiverId]!.indexWhere((m) => m.id == message.id || m.timestamp.isAtSameMomentAs(message.timestamp));
            if (index != -1) {
              _messagesByUser[receiverId]![index] = _messagesByUser[receiverId]![index].copyWith(isSent: true);
            }
          }
          notifyListeners();
          return;
        }

        // Get shared key for this user
        final otherUserId = message.senderId;

        String? sharedKey = _sharedKeys[otherUserId];
        if (sharedKey == null) {
          sharedKey = await _db.getSharedKey(otherUserId);
          if (sharedKey != null) {
            _sharedKeys[otherUserId] = sharedKey;
          }
        }

        // Decrypt message if we have the key
        String decryptedContent = message.content;
        if (sharedKey != null) {
          try {
            decryptedContent = await _cryptoService.decryptMessage(
              message.content,
              sharedKey,
            );
          } catch (e) {
            print('Decryption failed: $e');
          }
        }

        final decryptedMessage = message.copyWith(content: decryptedContent);

        // Save to local database
        await _db.insertMessage(decryptedMessage.toDatabase());

        // Update in-memory messages
        if (!_messagesByUser.containsKey(otherUserId)) {
          _messagesByUser[otherUserId] = [];
        }
        _messagesByUser[otherUserId]!.add(decryptedMessage);

        // Refresh conversations
        await loadConversations();

        notifyListeners();
      } catch (e) {
        print('Error handling received message: $e');
      }
    };

    // Handle typing status
    _socketService.onUserTyping = (userId, isTyping) {
      _typingStatus[userId] = isTyping;
      notifyListeners();
    };

    // Handle notifications
    _socketService.onNewMessageNotification = (senderId, messageType) {
      // Could show a notification here
      print('New message from $senderId');
    };
  }

  // Register new user
  Future<void> register(String username, String email, String password) async {
    try {
      print('Starting registration for: $username');

      // Generate ECDH key pair (for 1-1 messaging)
      final ecdhKeys = await _cryptoService.generateKeyPair();
      print('Generated ECDH keys - publicKey length: ${ecdhKeys['publicKey']?.length}');

      if (ecdhKeys['publicKey'] == null || ecdhKeys['publicKey']!.isEmpty) {
        throw Exception('Failed to generate ECDH public key');
      }

      // Generate RSA key pair (for group chat session keys)
      print('Generating RSA keys for group chat...');
      final rsaKeys = await _cryptoService.generateRSAKeyPair();
      print('Generated RSA keys - publicKey length: ${rsaKeys['publicKey']?.length}');

      // Register with server (send ECDH public key for backward compatibility)
      print('Sending registration request...');
      final response = await _apiService.register(
        username,
        email,
        password,
        ecdhKeys['publicKey']!,
      );
      print('Registration response received');

      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      // Set API token
      _apiService.setToken(_token!);

      // Connect socket
      _socketService.connect(_token!);

      // Save user to local db
      await _db.insertUser(_currentUser!.toDatabase());

      notifyListeners();
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Login user
  Future<void> login(String username, String password) async {
    try {
      final response = await _apiService.login(username, password);

      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      // Set API token
      _apiService.setToken(_token!);

      // Ensure RSA keys exist (for old users who registered before group chat)
      await KeyMigrationHelper.ensureRSAKeysExist();

      // Connect socket
      _socketService.connect(_token!);

      // Save user to local db
      await _db.insertUser(_currentUser!.toDatabase());

      // Load conversations
      await loadConversations();

      notifyListeners();
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    _socketService.disconnect();
    _apiService.clearToken();
    _currentUser = null;
    _token = null;
    _conversations = [];
    _messagesByUser = {};
    _sharedKeys = {};
    notifyListeners();
  }

  // Load conversations
  Future<void> loadConversations() async {
    try {
      // Load from local database first (fast)
      final localConvs = await _db.getConversations(_currentUser!.id);
      print('📋 Loaded ${localConvs.length} conversations from database');
      _conversations = localConvs
          .map((c) => Conversation.fromDatabase(c))
          .toList();
      notifyListeners();

      // Then sync with server (if online)
      if (_socketService.isConnected) {
        // Could merge server data here if needed
        // final serverConvs = await _apiService.getConversations();
      }
    } catch (e) {
      print('Load conversations error: $e');
    }
  }

  // Load messages for a user
  Future<void> loadMessages(String userId) async {
    try {
      // Load from local database
      final localMessages = await _db.getMessages(_currentUser!.id, userId);
      _messagesByUser[userId] = localMessages
          .map((m) => Message.fromDatabase(m))
          .toList()
          .reversed
          .toList();

      notifyListeners();

      // Mark as read
      await _db.markMessagesAsRead(_currentUser!.id, userId);
    } catch (e) {
      print('Load messages error: $e');
    }
  }

  // Send message
  Future<void> sendMessage(
    String receiverId,
    String content,
    String messageType, {
    String? fileUrl,
    String? encryptedFileKey,
    bool isForwarded = false,
    String? originalSenderId,
    String? forwardedFrom,
  }) async {
    try {
      // Get or create shared key
      String? sharedKey = _sharedKeys[receiverId];

      if (sharedKey == null) {
        // Load from database
        sharedKey = await _db.getSharedKey(receiverId);

        if (sharedKey == null) {
          // Compute new shared key
          final myKeys = await _cryptoService.getStoredKeys();
          final receiverData = await _apiService.getUserPublicKey(receiverId);

          sharedKey = await _cryptoService.computeSharedSecret(
            myKeys!['privateKey']!,
            receiverData['publicKey'],
          );

          // Save for future use
          await _db.saveSharedKey(receiverId, sharedKey);
        }

        _sharedKeys[receiverId] = sharedKey;
      }

      // For forwarded messages, content is already encrypted for this recipient
      // For new messages, encrypt the content
      final encryptedContent = isForwarded
          ? content // Already encrypted by ForwardService
          : await _cryptoService.encryptMessage(content, sharedKey);

      // Create message object
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: _currentUser!.id,
        receiverId: receiverId,
        content: isForwarded
            ? content
            : content, // For forwarded, store encrypted (already decrypted by ForwardService)
        messageType: messageType,
        timestamp: DateTime.now(),
        isSent: false,
        isForwarded: isForwarded,
        originalSenderId: originalSenderId,
        forwardedFrom: forwardedFrom,
        fileUrl: fileUrl,
        encryptedFileKey: encryptedFileKey,
      );

      // Save to local database
      await _db.insertMessage(message.toDatabase());

      // Add to UI immediately
      if (!_messagesByUser.containsKey(receiverId)) {
        _messagesByUser[receiverId] = [];
      }
      _messagesByUser[receiverId]!.add(message);
      notifyListeners();

      // Send encrypted version via socket
      _socketService.sendMessage(
        receiverId: receiverId,
        content: encryptedContent,
        messageType: messageType,
        isForwarded: isForwarded,
        originalSenderId: originalSenderId,
        forwardedFrom: forwardedFrom,
        fileUrl: fileUrl,
        encryptedFileKey: encryptedFileKey,
      );

      // Join room if not already
      _socketService.joinRoom(receiverId);
    } catch (e) {
      print('Send message error: $e');
      rethrow;
    }
  }

  // Send typing indicator
  void sendTyping(String receiverId, bool isTyping) {
    _socketService.sendTyping(receiverId, isTyping);
  }

  // Upload file
  Future<String> uploadFile(String filePath) async {
    try {
      final response = await _apiService.uploadFile(filePath);
      return response['fileUrl'];
    } catch (e) {
      print('Upload file error: $e');
      rethrow;
    }
  }

  // Search users
  Future<List<User>> searchUsers(String query) async {
    try {
      final results = await _apiService.searchUsers(query);
      return results.map((u) => User.fromJson(u)).toList();
    } catch (e) {
      print('Search users error: $e');
      return [];
    }
  }

  // Upload avatar
  Future<void> uploadAvatar(String filePath) async {
    try {
      final response = await _apiService.uploadAvatar(filePath);
      _currentUser = User.fromJson(response['user']);
      notifyListeners();
    } catch (e) {
      print('Upload avatar error: $e');
      rethrow;
    }
  }

  // Update profile
  Future<void> updateProfile(String email) async {
    try {
      final response = await _apiService.updateProfile(email);
      _currentUser = User.fromJson(response['user']);
      notifyListeners();
    } catch (e) {
      print('Update profile error: $e');
      rethrow;
    }
  }

  // Delete avatar
  Future<void> deleteAvatar() async {
    try {
      final response = await _apiService.deleteAvatar();
      _currentUser = User.fromJson(response['user']);
      notifyListeners();
    } catch (e) {
      print('Delete avatar error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }
}
