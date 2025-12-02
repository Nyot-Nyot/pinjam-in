import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/unauthorized_screen.dart';
import 'exceptions.dart';
import 'logger.dart' as logger;

/// Utility functions untuk admin authorization
class AdminGuard {
  /// Check apakah user adalah admin, throw exception jika bukan
  /// 
  /// Gunakan di dalam methods/functions yang hanya boleh diakses admin
  /// 
  /// Throws:
  /// - [UnauthorizedException] jika user tidak login
  /// - [ForbiddenException] jika user login tapi bukan admin
  /// 
  /// Example:
  /// ```dart
  /// Future<void> deleteUser(String userId) async {
  ///   AdminGuard.requireAdmin(authProvider);
  ///   // ... delete logic
  /// }
  /// ```
  static void requireAdmin(AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      logger.AppLogger.warning('Unauthorized access attempt - not authenticated');
      throw UnauthorizedException('You must be logged in to access this resource');
    }

    if (!authProvider.isAdmin) {
      logger.AppLogger.warning(
        'Forbidden access attempt by user: ${authProvider.userEmail}',
      );
      throw ForbiddenException(
        'You do not have permission to access this resource',
      );
    }

    logger.AppLogger.info('Admin access granted: ${authProvider.userEmail}');
  }

  /// Check apakah user punya permission tertentu
  /// 
  /// Throws:
  /// - [UnauthorizedException] jika user tidak login
  /// - [ForbiddenException] jika user tidak punya permission
  /// 
  /// Example:
  /// ```dart
  /// AdminGuard.requirePermission(authProvider, 'users:delete');
  /// ```
  static void requirePermission(
    AuthProvider authProvider,
    String permission,
  ) {
    if (!authProvider.isAuthenticated) {
      logger.AppLogger.warning('Unauthorized access attempt - not authenticated');
      throw UnauthorizedException('You must be logged in to access this resource');
    }

    if (!authProvider.hasPermission(permission)) {
      logger.AppLogger.warning(
        'Forbidden access attempt by user ${authProvider.userEmail} for permission: $permission',
      );
      throw ForbiddenException(
        'You do not have permission: $permission',
      );
    }

    logger.AppLogger.info(
      'Permission granted: $permission for ${authProvider.userEmail}',
    );
  }
}

/// Widget guard untuk protect admin routes
/// 
/// Gunakan untuk wrap admin screens/widgets.
/// Jika user bukan admin, akan show unauthorized screen.
/// Jika user belum login, akan redirect ke login.
/// 
/// Example:
/// ```dart
/// AdminGuardWidget(
///   child: AdminDashboardScreen(),
/// )
/// ```
class AdminGuardWidget extends StatelessWidget {
  const AdminGuardWidget({
    required this.child,
    this.redirectToLogin = true,
    super.key,
  });

  final Widget child;
  final bool redirectToLogin;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Not authenticated - redirect to login
    if (!authProvider.isAuthenticated) {
      logger.AppLogger.warning('AdminGuard: User not authenticated');
      
      if (redirectToLogin) {
        // Navigate to login after frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }
      
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Authenticated but not admin - show unauthorized
    if (!authProvider.isAdmin) {
      logger.AppLogger.warning(
        'AdminGuard: Forbidden access by ${authProvider.userEmail}',
      );
      return const UnauthorizedScreen();
    }

    // Admin - show content
    logger.AppLogger.info('AdminGuard: Access granted to ${authProvider.userEmail}');
    return child;
  }
}
