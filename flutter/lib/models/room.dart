/**
 * Room Model - Represents a Group Chat Room
 * 
 * Corresponds to backend Room schema
 */
class Room {
  final String id;
  final String name;
  final String? avatar;
  final String? description;
  final String type; // 'group' or 'channel'
  final String ownerId;
  final bool isPasswordProtected;
  final bool isPrivate; // Whether group is private or public
  final int memberCount;
  final int sessionKeyVersion;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final RoomSettings? settings;

  Room({
    required this.id,
    required this.name,
    this.avatar,
    this.description,
    required this.type,
    required this.ownerId,
    required this.isPasswordProtected,
    this.isPrivate = false,
    required this.memberCount,
    required this.sessionKeyVersion,
    required this.createdAt,
    this.lastMessageAt,
    this.settings,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    // Helper to safely get string value
    String getStringValue(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }
    
    return Room(
      id: getStringValue(json['id'] ?? json['_id']),
      name: getStringValue(json['name']),
      avatar: json['avatar']?.toString(),
      description: json['description']?.toString(),
      type: getStringValue(json['type'] ?? 'group'),
      ownerId: getStringValue(
        json['ownerId'] ?? json['owner']?['id'] ?? json['owner']?['_id'] ?? json['owner']
      ),
      isPasswordProtected: json['isPasswordProtected'] ?? false,
      isPrivate: json['isPrivate'] ?? false,
      memberCount: (json['memberCount'] ?? 0) as int,
      sessionKeyVersion: (json['sessionKeyVersion'] ?? 1) as int,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'].toString())
          : null,
      settings: json['settings'] != null
          ? RoomSettings.fromJson(json['settings'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'description': description,
      'type': type,
      'owner_id': ownerId,
      'is_password_protected': isPasswordProtected ? 1 : 0,
      'member_count': memberCount,
      'session_key_version': sessionKeyVersion,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }

  // SQLite database methods
  factory Room.fromDatabase(Map<String, dynamic> row) {
    return Room(
      id: row['id'] as String,
      name: row['name'] as String,
      avatar: row['avatar'] as String?,
      description: row['description'] as String?,
      type: row['type'] as String,
      ownerId: row['owner_id'] as String,
      isPasswordProtected: (row['is_password_protected'] as int) == 1,
      isPrivate: (row['is_private'] as int?) == 1,
      memberCount: row['member_count'] as int,
      sessionKeyVersion: row['session_key_version'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      lastMessageAt: row['last_message_at'] != null
          ? DateTime.parse(row['last_message_at'] as String)
          : null,
      settings: null, // Settings loaded separately if needed
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'description': description,
      'type': type,
      'owner_id': ownerId,
      'is_password_protected': isPasswordProtected ? 1 : 0,
      'is_private': isPrivate ? 1 : 0,
      'member_count': memberCount,
      'session_key_version': sessionKeyVersion,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
    };
  }

  Room copyWith({
    String? id,
    String? name,
    String? avatar,
    String? description,
    String? type,
    String? ownerId,
    bool? isPasswordProtected,
    bool? isPrivate,
    int? memberCount,
    int? sessionKeyVersion,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    RoomSettings? settings,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      description: description ?? this.description,
      type: type ?? this.type,
      ownerId: ownerId ?? this.ownerId,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      isPrivate: isPrivate ?? this.isPrivate,
      memberCount: memberCount ?? this.memberCount,
      sessionKeyVersion: sessionKeyVersion ?? this.sessionKeyVersion,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      settings: settings ?? this.settings,
    );
  }
}

/**
 * Room Settings Model
 */
class RoomSettings {
  final bool allowMembersToInvite;
  final bool allowMembersToAddMembers;
  final int maxMembers;

  RoomSettings({
    required this.allowMembersToInvite,
    required this.allowMembersToAddMembers,
    required this.maxMembers,
  });

  factory RoomSettings.fromJson(Map<String, dynamic> json) {
    return RoomSettings(
      allowMembersToInvite: json['allowMembersToInvite'] ?? true,
      allowMembersToAddMembers: json['allowMembersToAddMembers'] ?? false,
      maxMembers: json['maxMembers'] ?? 500,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowMembersToInvite': allowMembersToInvite,
      'allowMembersToAddMembers': allowMembersToAddMembers,
      'maxMembers': maxMembers,
    };
  }
}
