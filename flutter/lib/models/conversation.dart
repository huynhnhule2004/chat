class Conversation {
  final String userId;
  final String username;
  final String lastMessage;
  final DateTime lastTimestamp;
  final String messageType;
  final int unreadCount;
  final String? avatar;

  Conversation({
    required this.userId,
    required this.username,
    required this.lastMessage,
    required this.lastTimestamp,
    this.messageType = 'text',
    this.unreadCount = 0,
    this.avatar,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      userId: json['userId'] ?? json['user_id'] ?? '',
      username: json['username'] ?? '',
      lastMessage: json['lastMessage']?['content'] ?? json['last_message'] ?? '',
      lastTimestamp: json['lastMessage']?['timestamp'] != null
          ? DateTime.parse(json['lastMessage']['timestamp'])
          : DateTime.fromMillisecondsSinceEpoch(json['last_timestamp'] ?? 0),
      messageType: json['lastMessage']?['messageType'] ?? json['message_type'] ?? 'text',
      unreadCount: json['unreadCount'] ?? 0,
      avatar: json['avatar'],
    );
  }

  factory Conversation.fromDatabase(Map<String, dynamic> map) {
    return Conversation(
      userId: map['user_id'],
      username: map['username'],
      lastMessage: map['last_message'],
      lastTimestamp: DateTime.fromMillisecondsSinceEpoch(map['last_timestamp']),
      messageType: map['message_type'] ?? 'text',
      unreadCount: 0,
      avatar: map['avatar'],
    );
  }
}
