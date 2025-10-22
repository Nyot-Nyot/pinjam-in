import 'package:flutter/foundation.dart';

/// Centralized logging utility for the application.
/// Only logs in debug mode, prevents logs in production.
class AppLogger {
  AppLogger._();

  /// Log general information
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[INFO]';
      debugPrint('$prefix $message');
    }
  }

  /// Log warnings
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[WARNING]';
      debugPrint('⚠️ $prefix $message');
    }
  }

  /// Log errors with optional error object
  static void error(String message, [Object? error, String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[ERROR]';
      debugPrint('❌ $prefix $message');
      if (error != null) {
        debugPrint('   Error details: $error');
      }
    }
  }

  /// Log debug information (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[DEBUG]';
      debugPrint('🔍 $prefix $message');
    }
  }

  /// Log success messages
  static void success(String message, [String? tag]) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[SUCCESS]';
      debugPrint('✅ $prefix $message');
    }
  }
}
