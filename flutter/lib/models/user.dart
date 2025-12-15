class User {
  final String id;
  final String username;
  final String publicKey;

  User({
    required this.id,
    required this.username,
    required this.publicKey,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      publicKey: json['publicKey'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'publicKey': publicKey,
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
      publicKey: map['public_key'],
    );
  }
}
