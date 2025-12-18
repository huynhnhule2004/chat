class User {
  final String id;
  final String username;
  final String email;
  final String? avatar;
  final String publicKey;
  final String role;
  final bool isActive;
  final bool isBanned;
  final DateTime? lastActive;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    required this.publicKey,
    this.role = 'user',
    this.isActive = true,
    this.isBanned = false,
    this.lastActive,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      publicKey: json['publicKey'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      isBanned: json['isBanned'] ?? false,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'publicKey': publicKey,
      'role': role,
      'isActive': isActive,
      'isBanned': isBanned,
      'lastActive': lastActive?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'username': username,
      'public_key': publicKey,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory User.fromDatabase(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: '',
      publicKey: map['public_key'],
    );
  }
}
