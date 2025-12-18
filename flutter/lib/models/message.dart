class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content; // Encrypted content
  final String messageType; // text, image, video, file
  final DateTime timestamp;
  final bool isSent;
  final bool isRead;

  // Forward message fields
  final bool isForwarded;
  final String? originalSenderId;
  final String? forwardedFrom; // Original sender's username

  // File encryption fields (hybrid encryption)
  final String? fileUrl;
  final String?
  encryptedFileKey; // Symmetric key encrypted with recipient's public key
  final int? fileSize;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    required this.timestamp,
    this.isSent = false,
    this.isRead = false,
    this.isForwarded = false,
    this.originalSenderId,
    this.forwardedFrom,
    this.fileUrl,
    this.encryptedFileKey,
    this.fileSize,
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
      isForwarded: json['isForwarded'] == 1 || json['isForwarded'] == true,
      originalSenderId: json['originalSenderId'],
      forwardedFrom: json['forwardedFrom'],
      fileUrl: json['fileUrl'],
      encryptedFileKey: json['encryptedFileKey'],
      fileSize: json['fileSize'],
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
      'isForwarded': isForwarded,
      if (originalSenderId != null) 'originalSenderId': originalSenderId,
      if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (encryptedFileKey != null) 'encryptedFileKey': encryptedFileKey,
      if (fileSize != null) 'fileSize': fileSize,
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
      'is_forwarded': isForwarded ? 1 : 0,
      'original_sender_id': originalSenderId,
      'forwarded_from': forwardedFrom,
      'file_url': fileUrl,
      'encrypted_file_key': encryptedFileKey,
      'file_size': fileSize,
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
      isForwarded: map['is_forwarded'] == 1,
      originalSenderId: map['original_sender_id'],
      forwardedFrom: map['forwarded_from'],
      fileUrl: map['file_url'],
      encryptedFileKey: map['encrypted_file_key'],
      fileSize: map['file_size'],
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
    bool? isForwarded,
    String? originalSenderId,
    String? forwardedFrom,
    String? fileUrl,
    String? encryptedFileKey,
    int? fileSize,
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
      isForwarded: isForwarded ?? this.isForwarded,
      originalSenderId: originalSenderId ?? this.originalSenderId,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      fileUrl: fileUrl ?? this.fileUrl,
      encryptedFileKey: encryptedFileKey ?? this.encryptedFileKey,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
