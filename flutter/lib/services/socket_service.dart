import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../models/message.dart';

class SocketService {
  static final SocketService instance = SocketService._init();
  IO.Socket? _socket;
  bool _isConnected = false;

  // Callbacks
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String userId, bool isTyping)? onUserTyping;
  Function(String userId)? onUserOnline;
  Function(String userId)? onUserOffline;
  Function(String senderId, String messageType)? onNewMessageNotification;
  
  // Group chat callbacks
  Function(Message message)? onGroupMessageReceived;
  Function(Map<String, dynamic>)? onMemberJoinedGroup;
  Function(Map<String, dynamic>)? onMemberLeftGroup;

  SocketService._init();

  bool get isConnected => _isConnected;

  void connect(String token) {
    // If already connected, return
    if (_socket != null && _isConnected) {
      print('✓ Socket already connected');
      return;
    }

    // If socket exists but not connected, disconnect first
    if (_socket != null && !_isConnected) {
      print('🔄 Cleaning up old socket connection...');
      _socket!.dispose();
      _socket = null;
    }

    print('🔌 Connecting to socket: ${AppConfig.socketUrl}');
    
    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['polling', 'websocket']) // Try polling first, then websocket
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      print('✓ Socket connected successfully');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      print('✗ Socket disconnected');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      print('✗ Socket connection error: $error');
      _isConnected = false;
    });

    // Listen to message events
    _socket!.on('receive_message', (data) {
      print('📨 Message received: $data');
      if (onMessageReceived != null) {
        onMessageReceived!(Map<String, dynamic>.from(data));
      }
    });

    // Listen to typing events
    _socket!.on('user_typing', (data) {
      if (onUserTyping != null) {
        onUserTyping!(data['userId'], data['isTyping']);
      }
    });

    // Listen to online/offline events
    _socket!.on('user_online', (data) {
      if (onUserOnline != null) {
        onUserOnline!(data['userId']);
      }
    });

    _socket!.on('user_offline', (data) {
      if (onUserOffline != null) {
        onUserOffline!(data['userId']);
      }
    });

    // Listen to new message notifications
    _socket!.on('new_message_notification', (data) {
      if (onNewMessageNotification != null) {
        onNewMessageNotification!(data['senderId'], data['messageType']);
      }
    });

    _socket!.on('message_error', (data) {
      print('✗ Message error: $data');
    });

    // Group chat events
    _socket!.on('receive_group_message', (data) {
      print('📨 Group message received: $data');
      if (onGroupMessageReceived != null) {
        // Backend sends message data directly, not wrapped in 'message' field
        onGroupMessageReceived!(Message.fromJson(data));
      }
    });

    _socket!.on('member_joined', (data) {
      print('👤 Member joined group: ${data['username']}');
      if (onMemberJoinedGroup != null) {
        onMemberJoinedGroup!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('member_left', (data) {
      print('👤 Member left group: ${data['username']}');
      if (onMemberLeftGroup != null) {
        onMemberLeftGroup!(Map<String, dynamic>.from(data));
      }
    });
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }

  // Join a conversation room
  void joinRoom(String receiverId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_room', {'receiverId': receiverId});
      print('✓ Joined room with: $receiverId');
    }
  }

  // Send a message
  void sendMessage({
    required String receiverId,
    required String content,
    String messageType = 'text',
    bool isForwarded = false,
    String? originalSenderId,
    String? forwardedFrom,
    String? fileUrl,
    String? encryptedFileKey,
  }) {
    if (_socket != null && _isConnected) {
      final payload = {
        'receiverId': receiverId,
        'content': content,
        'messageType': messageType,
        'isForwarded': isForwarded,
        if (originalSenderId != null) 'originalSenderId': originalSenderId,
        if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (encryptedFileKey != null) 'encryptedFileKey': encryptedFileKey,
      };
      _socket!.emit('send_message', payload);
      print('✉️ Message sent to: $receiverId');
    }
  }

  // Group chat methods
  void joinGroup(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_group', {'roomId': roomId});
      print('✓ Joined group: $roomId');
    }
  }

  void leaveGroup(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_group', {'roomId': roomId});
      print('✓ Left group: $roomId');
    }
  }

  void sendGroupMessage({
    required String roomId,
    required String encryptedContent,
    required String iv,
    required String authTag,
    String messageType = 'text',
    String? fileUrl,
    String? encryptedFileKey,
  }) {
    if (_socket != null && _isConnected) {
      final payload = {
        'roomId': roomId,
        'content': encryptedContent,
        'iv': iv,
        'authTag': authTag,
        'messageType': messageType,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (encryptedFileKey != null) 'encryptedFileKey': encryptedFileKey,
      };

      _socket!.emit('send_group_message', payload);
      print('✓ Group message sent to room: $roomId');
    } else {
      print('✗ Socket not connected. Cannot send group message.');
    }
  }

  void sendGroupTyping(String roomId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('group_typing', {'roomId': roomId, 'isTyping': isTyping});
    }
  }

  // Set callback for group messages
  void onGroupMessage(Function(Message) callback) {
    onGroupMessageReceived = callback;
  }

  void onMemberJoined(Function(Map<String, dynamic>) callback) {
    onMemberJoinedGroup = callback;
  }

  void onMemberLeft(Function(Map<String, dynamic>) callback) {
    onMemberLeftGroup = callback;
  }

  // Send typing indicator
  void sendTyping(String receiverId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {'receiverId': receiverId, 'isTyping': isTyping});
    }
  }

  void dispose() {
    disconnect();
  }
}
