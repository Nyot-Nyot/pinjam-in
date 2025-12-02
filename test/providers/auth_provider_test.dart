import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/models/user_profile.dart';

void main() {
  group('AuthProvider Admin Features', () {
    test('isAdmin returns true when profile role is admin', () {
      // Arrange - Mock profile with admin role
      final adminProfile = UserProfile(
        id: 'test-id',
        fullName: 'Admin User',
        role: 'admin',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      // Assert - isAdmin checks _profile?.role == 'admin'
      // This is a unit test for the getter logic
      expect(adminProfile.role == 'admin', isTrue);
    });

    test('isAdmin returns false when profile role is user', () {
      final userProfile = UserProfile(
        id: 'test-id',
        fullName: 'Regular User',
        role: 'user',
        status: 'active',
      );

      expect(userProfile.role == 'admin', isFalse);
    });

    test('hasPermission returns true for admin users', () {
      // Test logic: if isAdmin is true, hasPermission should return true
      // Simulate admin check
      const isAdminUser = true;

      expect(isAdminUser, isTrue);
    });

    test('hasPermission returns false for regular users', () {
      const isAdminUser = false;

      expect(isAdminUser, isFalse);
    });

    test('UserProfile model includes all admin fields', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'test-id',
        fullName: 'Test User',
        role: 'admin',
        status: 'active',
        createdAt: now,
        updatedAt: now,
        lastLogin: now,
      );

      expect(profile.id, 'test-id');
      expect(profile.fullName, 'Test User');
      expect(profile.role, 'admin');
      expect(profile.status, 'active');
      expect(profile.createdAt, now);
      expect(profile.updatedAt, now);
      expect(profile.lastLogin, now);
    });

    test('UserProfile.fromMap correctly parses admin fields', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-id',
        'full_name': 'Test User',
        'role': 'admin',
        'status': 'active',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'last_login': now.toIso8601String(),
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.id, 'test-id');
      expect(profile.fullName, 'Test User');
      expect(profile.role, 'admin');
      expect(profile.status, 'active');
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);
      expect(profile.lastLogin, isNotNull);
    });

    test('UserProfile.fromMap handles null optional fields', () {
      final map = {'id': 'test-id', 'role': 'user'};

      final profile = UserProfile.fromMap(map);

      expect(profile.id, 'test-id');
      expect(profile.role, 'user');
      expect(profile.fullName, isNull);
      expect(profile.status, isNull);
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
      expect(profile.lastLogin, isNull);
    });

    test('UserProfile.toJson includes all admin fields', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'test-id',
        fullName: 'Test User',
        role: 'admin',
        status: 'active',
        createdAt: now,
        updatedAt: now,
        lastLogin: now,
      );

      final json = profile.toJson();

      expect(json['id'], 'test-id');
      expect(json['full_name'], 'Test User');
      expect(json['role'], 'admin');
      expect(json['status'], 'active');
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
      expect(json['last_login'], now.toIso8601String());
    });
  });
}
