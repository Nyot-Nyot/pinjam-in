class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    required this.role,
    this.updatedAt,
  });

  final String id;
  final String? fullName;
  final String role; // 'user' | 'admin'
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role': role,
    'updated_at': updatedAt?.toIso8601String(),
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
      updatedAt: parseTs(m['updated_at']),
    );
  }
}
