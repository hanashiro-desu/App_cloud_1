class Account {
  final String email;
  final String password;

  Account({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    email: json['email'] as String,
    password: json['password'] as String,
  );

  @override
  String toString() => 'Account(email: $email)';
}

class Profile {
  final String? id; // uuid trong Supabase -> có thể null khi chưa insert
  final String? userId; // liên kết với auth.users.id
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String? bio;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActive;
  final int storageQuota; // int4, dung lượng tối đa (MB)
  final String authProvider; // local, google, github, ...

  Profile({
    this.id,
    this.userId,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
    this.lastActive,
    this.storageQuota = 1024, // mặc định 1GB nếu chưa có giá trị
    this.authProvider = 'local',
  });

  /// Convert từ Supabase JSON → Dart object
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String?,
    userId: json['user_id'] as String?,
    email: json['email'] as String?,
    fullName: json['full_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    phone: json['phone'] as String?,
    bio: json['bio'] as String?,
    dateOfBirth: json['date_of_birth'] != null
        ? DateTime.parse(json['date_of_birth'])
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : null,
    lastActive: json['last_active'] != null
        ? DateTime.parse(json['last_active'])
        : null,
    storageQuota: (json['storage_quota'] ?? 1024) as int,
    authProvider: json['auth_provider'] ?? 'local',
  );

  /// Convert Dart object → JSON để gửi lên Supabase
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'phone': phone,
    'bio': bio,
    'date_of_birth': dateOfBirth?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'last_active': lastActive?.toIso8601String(),
    'storage_quota': storageQuota,
    'auth_provider': authProvider,
  };

  Profile copyWith({
    String? id,
    String? userId,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? bio,
    DateTime? dateOfBirth,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActive,
    int? storageQuota,
    String? authProvider,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActive: lastActive ?? this.lastActive,
      storageQuota: storageQuota ?? this.storageQuota,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  @override
  String toString() =>
      'Profile(id: $id, userId: $userId, email: $email, fullName: $fullName, provider: $authProvider)';
}
