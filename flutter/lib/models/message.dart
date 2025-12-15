class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content; // Encrypted content
  final String messageType; // text, image, video, file
  final DateTime timestamp;
  final bool isSent;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    required this.timestamp,
    this.isSent = false,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? json['_id'] ?? '',
      senderId: json['sender'] ?? json['senderId'] ?? '',
      receiverId: json['receiver'] ?? json['receiverId'] ?? '',
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'text',
      timestamp: json['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : DateTime.parse(json['timestamp']),
      isSent: json['isSent'] == 1 || json['isSent'] == true,
      isRead: json['isRead'] == 1 || json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'messageType': messageType,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent,
      'isRead': isRead,
    };
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_sent': isSent ? 1 : 0,
      'is_read': isRead ? 1 : 0,
    };
  }

  factory Message.fromDatabase(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderId: map['sender_id'],
      receiverId: map['receiver_id'],
      content: map['content'],
      messageType: map['message_type'] ?? 'text',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isSent: map['is_sent'] == 1,
      isRead: map['is_read'] == 1,
    );
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    String? messageType,
    DateTime? timestamp,
    bool? isSent,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      isRead: isRead ?? this.isRead,
    );
  }
}
