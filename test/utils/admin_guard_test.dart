import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/utils/admin_guard.dart';
import 'package:pinjam_in/utils/exceptions.dart';
import 'package:pinjam_in/providers/auth_provider.dart';

// Mock AuthProvider untuk testing
class MockAuthProvider extends AuthProvider {
  MockAuthProvider({
    required this.mockIsAuthenticated,
    required this.mockIsAdmin,
    this.mockUserEmail,
    this.mockPermissions = const {},
  });

  final bool mockIsAuthenticated;
  final bool mockIsAdmin;
  final String? mockUserEmail;
  final Set<String> mockPermissions;

  @override
  bool get isAuthenticated => mockIsAuthenticated;

  @override
  bool get isAdmin => mockIsAdmin;

  @override
  String? get userEmail => mockUserEmail;

  @override
  bool hasPermission(String permission) {
    if (mockIsAdmin) return true;
    return mockPermissions.contains(permission);
  }
}

void main() {
  group('AdminGuard.requireAdmin', () {
    test('should throw UnauthorizedException when not authenticated', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: false,
        mockIsAdmin: false,
      );

      expect(
        () => AdminGuard.requireAdmin(authProvider),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('should throw ForbiddenException when authenticated but not admin', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: true,
        mockIsAdmin: false,
        mockUserEmail: 'user@example.com',
      );

      expect(
        () => AdminGuard.requireAdmin(authProvider),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('should not throw when authenticated and is admin', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: true,
        mockIsAdmin: true,
        mockUserEmail: 'admin@example.com',
      );

      expect(
        () => AdminGuard.requireAdmin(authProvider),
        returnsNormally,
      );
    });
  });

  group('AdminGuard.requirePermission', () {
    test('should throw UnauthorizedException when not authenticated', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: false,
        mockIsAdmin: false,
      );

      expect(
        () => AdminGuard.requirePermission(authProvider, 'users:read'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('should throw ForbiddenException when no permission', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: true,
        mockIsAdmin: false,
        mockUserEmail: 'user@example.com',
        mockPermissions: {'items:read'},
      );

      expect(
        () => AdminGuard.requirePermission(authProvider, 'users:delete'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('should not throw when user has specific permission', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: true,
        mockIsAdmin: false,
        mockUserEmail: 'user@example.com',
        mockPermissions: {'users:read', 'items:read'},
      );

      expect(
        () => AdminGuard.requirePermission(authProvider, 'users:read'),
        returnsNormally,
      );
    });

    test('should not throw when user is admin (has all permissions)', () {
      final authProvider = MockAuthProvider(
        mockIsAuthenticated: true,
        mockIsAdmin: true,
        mockUserEmail: 'admin@example.com',
      );

      expect(
        () => AdminGuard.requirePermission(authProvider, 'users:delete'),
        returnsNormally,
      );
    });
  });

  group('Custom Exceptions', () {
    test('UnauthorizedException has correct message', () {
      final exception = UnauthorizedException('Custom message');
      expect(exception.message, 'Custom message');
      expect(exception.toString(), contains('UnauthorizedException'));
      expect(exception.toString(), contains('Custom message'));
    });

    test('UnauthorizedException has default message', () {
      final exception = UnauthorizedException();
      expect(exception.message, 'Unauthorized access');
    });

    test('ForbiddenException has correct message', () {
      final exception = ForbiddenException('No permission');
      expect(exception.message, 'No permission');
      expect(exception.toString(), contains('ForbiddenException'));
      expect(exception.toString(), contains('No permission'));
    });

    test('ForbiddenException has default message', () {
      final exception = ForbiddenException();
      expect(exception.message, 'Forbidden: insufficient permissions');
    });
  });
}
