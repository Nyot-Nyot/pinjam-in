class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    required this.role,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  final String id;
  final String? fullName;
  final String role; // 'user' | 'admin'
  final String? status; // 'active' | 'inactive' | 'suspended'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role': role,
    'status': status,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'last_login': lastLogin?.toIso8601String(),
  };

  static UserProfile fromMap(Map<String, dynamic> m) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    return UserProfile(
      id: m['id'] as String,
      fullName: m['full_name'] as String?,
      role: (m['role'] as String?) ?? 'user',
      status: m['status'] as String?,
      createdAt: parseTs(m['created_at']),
      updatedAt: parseTs(m['updated_at']),
      lastLogin: parseTs(m['last_login']),
    );
  }
}
