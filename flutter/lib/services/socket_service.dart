import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

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

  SocketService._init();

  bool get isConnected => _isConnected;

  void connect(String token) {
    if (_socket != null && _isConnected) {
      print('Socket already connected');
      return;
    }

    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      print('✓ Socket connected');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      print('✗ Socket disconnected');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      print('✗ Connection error: $error');
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
  }) {
    if (_socket != null && _isConnected) {
      _socket!.emit('send_message', {
        'receiverId': receiverId,
        'content': content,
        'messageType': messageType,
      });
      print('✓ Message sent to: $receiverId');
    } else {
      print('✗ Socket not connected. Cannot send message.');
    }
  }

  // Send typing indicator
  void sendTyping(String receiverId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {
        'receiverId': receiverId,
        'isTyping': isTyping,
      });
    }
  }

  void dispose() {
    disconnect();
  }
}
