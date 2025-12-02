import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/models/user_profile.dart';

void main() {
  test('UserProfile.fromMap parses fields correctly', () {
    final map = {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'full_name': 'Alice Example',
      'role': 'admin',
      'updated_at': '2025-11-14T12:00:00Z',
    };

    final p = UserProfile.fromMap(map);

    expect(p.id, map['id']);
    expect(p.fullName, 'Alice Example');
    expect(p.role, 'admin');
    expect(p.updatedAt?.toUtc().toIso8601String(), '2025-11-14T12:00:00.000Z');
  });
}
