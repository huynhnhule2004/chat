import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/crypto_service.dart';
import '../database/database_helper.dart';

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
        
        // Get shared key for this user
        final otherUserId = message.senderId == _currentUser?.id 
            ? message.receiverId 
            : message.senderId;
        
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
  Future<void> register(String username, String password) async {
    try {
      print('Starting registration for: $username');
      
      // Generate key pair
      final keys = await _cryptoService.generateKeyPair();
      print('Generated keys - publicKey length: ${keys['publicKey']?.length}');
      
      if (keys['publicKey'] == null || keys['publicKey']!.isEmpty) {
        throw Exception('Failed to generate public key');
      }
      
      // Register with server
      print('Sending registration request...');
      final response = await _apiService.register(
        username,
        password,
        keys['publicKey']!,
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
      _conversations = localConvs.map((c) => Conversation.fromDatabase(c)).toList();
      notifyListeners();

      // Then sync with server (if online)
      if (_socketService.isConnected) {
        final serverConvs = await _apiService.getConversations();
        // Could merge server data here if needed
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
  Future<void> sendMessage(String receiverId, String content, {String messageType = 'text'}) async {
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

      // Encrypt message
      final encryptedContent = await _cryptoService.encryptMessage(content, sharedKey);

      // Create message object
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: _currentUser!.id,
        receiverId: receiverId,
        content: content, // Store decrypted locally
        messageType: messageType,
        timestamp: DateTime.now(),
        isSent: false,
      );

      // Save to local database (decrypted)
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

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }
}
