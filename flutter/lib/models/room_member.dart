/**
 * RoomMember Model - Represents a member of a group chat room
 * 
 * Critical Security Component:
 * - Each member has their own encrypted copy of the SessionKey
 * - encryptedSessionKey: Encrypted with member's RSA public key
 * - Only this member can decrypt it with their private key
 */
class RoomMember {
  final String id;
  final String roomId;
  final String userId;
  final String encryptedSessionKey; // Base64 encoded RSA-encrypted session key
  final int sessionKeyVersion;
  final String role; // 'owner', 'admin', 'member'
  final DateTime joinedAt;
  final int unreadCount;
  final bool isMuted;
  final DateTime? mutedUntil;
  final bool isActive;

  // User info (populated from join)
  final String? username;
  final String? email;
  final String? avatar;

  RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.encryptedSessionKey,
    required this.sessionKeyVersion,
    required this.role,
    required this.joinedAt,
    this.unreadCount = 0,
    this.isMuted = false,
    this.mutedUntil,
    this.isActive = true,
    this.username,
    this.email,
    this.avatar,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] ?? json['_id'] ?? '',
      roomId: json['roomId'] ?? '',
      userId: json['userId'] ?? json['user']?['id'] ?? json['user']?['_id'] ?? '',
      encryptedSessionKey: json['encryptedSessionKey'] ?? '',
      sessionKeyVersion: json['sessionKeyVersion'] ?? 1,
      role: json['role'] ?? 'member',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
      isMuted: json['isMuted'] ?? false,
      mutedUntil: json['mutedUntil'] != null
          ? DateTime.parse(json['mutedUntil'])
          : null,
      isActive: json['isActive'] ?? true,
      username: json['username'] ?? json['user']?['username'],
      email: json['email'] ?? json['user']?['email'],
      avatar: json['avatar'] ?? json['user']?['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'userId': userId,
      'encryptedSessionKey': encryptedSessionKey,
      'sessionKeyVersion': sessionKeyVersion,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'unreadCount': unreadCount,
      'isMuted': isMuted,
      'mutedUntil': mutedUntil?.toIso8601String(),
      'isActive': isActive,
      'username': username,
      'email': email,
      'avatar': avatar,
    };
  }

  // SQLite database methods
  factory RoomMember.fromDatabase(Map<String, dynamic> row) {
    return RoomMember(
      id: row['id'] as String,
      roomId: row['room_id'] as String,
      userId: row['user_id'] as String,
      encryptedSessionKey: row['encrypted_session_key'] as String,
      sessionKeyVersion: row['session_key_version'] as int,
      role: row['role'] as String,
      joinedAt: DateTime.parse(row['joined_at'] as String),
      unreadCount: row['unread_count'] as int? ?? 0,
      isMuted: (row['is_muted'] as int? ?? 0) == 1,
      mutedUntil: row['muted_until'] != null
          ? DateTime.parse(row['muted_until'] as String)
          : null,
      isActive: (row['is_active'] as int? ?? 1) == 1,
      username: row['username'] as String?,
      email: row['email'] as String?,
      avatar: row['avatar'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'encrypted_session_key': encryptedSessionKey,
      'session_key_version': sessionKeyVersion,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'unread_count': unreadCount,
      'is_muted': isMuted ? 1 : 0,
      'muted_until': mutedUntil?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  // Check if member has latest key version
  bool hasLatestKey(int roomKeyVersion) {
    return sessionKeyVersion == roomKeyVersion;
  }

  // Create copy with updated fields
  RoomMember copyWith({
    String? encryptedSessionKey,
    int? sessionKeyVersion,
    int? unreadCount,
    bool? isMuted,
    DateTime? mutedUntil,
  }) {
    return RoomMember(
      id: id,
      roomId: roomId,
      userId: userId,
      encryptedSessionKey: encryptedSessionKey ?? this.encryptedSessionKey,
      sessionKeyVersion: sessionKeyVersion ?? this.sessionKeyVersion,
      role: role,
      joinedAt: joinedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      isActive: isActive,
      username: username,
      email: email,
      avatar: avatar,
    );
  }
}
