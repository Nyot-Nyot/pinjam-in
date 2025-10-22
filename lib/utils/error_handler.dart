import 'package:flutter/material.dart';

import 'logger.dart';

/// Centralized error handling and user-friendly message display.
/// Provides consistent error messaging throughout the app.
class ErrorHandler {
  ErrorHandler._(); // Private constructor to prevent instantiation

  // ==================== Error Message Mapping ====================

  /// Convert technical error to user-friendly message.
  ///
  /// Maps common error patterns to localized, understandable messages.
  static String getFriendlyMessage(dynamic error) {
    if (error == null) return 'Terjadi kesalahan yang tidak diketahui';

    final errorStr = error.toString().toLowerCase();

    // Network errors
    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('failed host lookup')) {
      return 'Koneksi internet bermasalah. Periksa koneksi Anda.';
    }

    // Authentication errors
    if (errorStr.contains('invalid login') ||
        errorStr.contains('invalid credentials') ||
        errorStr.contains('email not found') ||
        errorStr.contains('wrong password')) {
      return 'Email atau password salah';
    }

    if (errorStr.contains('email already') ||
        errorStr.contains('user already exists')) {
      return 'Email sudah terdaftar';
    }

    if (errorStr.contains('weak password')) {
      return 'Password terlalu lemah';
    }

    if (errorStr.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Periksa inbox Anda.';
    }

    if (errorStr.contains('not authenticated') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('session expired')) {
      return 'Sesi berakhir. Silakan login ulang.';
    }

    // Storage/Database errors
    if (errorStr.contains('permission denied') ||
        errorStr.contains('access denied')) {
      return 'Akses ditolak. Periksa izin aplikasi.';
    }

    if (errorStr.contains('storage') || errorStr.contains('bucket not found')) {
      return 'Gagal mengakses penyimpanan';
    }

    if (errorStr.contains('quota') || errorStr.contains('limit exceeded')) {
      return 'Batas penyimpanan tercapai';
    }

    // File/Image errors
    if (errorStr.contains('file not found') ||
        errorStr.contains('path not found')) {
      return 'File tidak ditemukan';
    }

    if (errorStr.contains('invalid image') ||
        errorStr.contains('unsupported format')) {
      return 'Format file tidak didukung';
    }

    if (errorStr.contains('file too large') || errorStr.contains('size')) {
      return 'Ukuran file terlalu besar';
    }

    // Validation errors
    if (errorStr.contains('required') || errorStr.contains('missing')) {
      return 'Data yang dibutuhkan tidak lengkap';
    }

    if (errorStr.contains('invalid format') || errorStr.contains('malformed')) {
      return 'Format data tidak valid';
    }

    // General fallback
    return 'Terjadi kesalahan: ${_truncateError(error.toString())}';
  }

  /// Truncate error message to reasonable length.
  static String _truncateError(String message, {int maxLength = 100}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  // ==================== Snackbar Display ====================

  /// Show error message in a snackbar.
  ///
  /// Automatically converts technical errors to user-friendly messages,
  /// logs the error for debugging, and displays a snackbar.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await riskyOperation();
  /// } catch (e) {
  ///   ErrorHandler.showError(context, e);
  /// }
  /// ```
  static void showError(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
  }) {
    // Log the error for debugging
    AppLogger.error('Error occurred', error, 'ErrorHandler');

    // Get user-friendly message
    final message = customMessage ?? getFriendlyMessage(error);

    // Show snackbar
    _showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.red.shade700,
      action: action,
    );
  }

  /// Show success message in a snackbar.
  ///
  /// Example:
  /// ```dart
  /// await saveData();
  /// ErrorHandler.showSuccess(context, 'Data berhasil disimpan');
  /// ```
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    AppLogger.success(message, 'ErrorHandler');

    _showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.green.shade700,
      action: action,
    );
  }

  /// Show info message in a snackbar.
  ///
  /// Example:
  /// ```dart
  /// ErrorHandler.showInfo(context, 'Data sedang disinkronkan...');
  /// ```
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    AppLogger.info(message, 'ErrorHandler');

    _showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.blue.shade700,
      action: action,
    );
  }

  /// Show warning message in a snackbar.
  ///
  /// Example:
  /// ```dart
  /// ErrorHandler.showWarning(context, 'Koneksi tidak stabil');
  /// ```
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    AppLogger.warning(message, 'ErrorHandler');

    _showSnackBar(
      context,
      message,
      duration: duration,
      backgroundColor: Colors.orange.shade700,
      action: action,
    );
  }

  /// Internal helper to show snackbar with consistent styling.
  static void _showSnackBar(
    BuildContext context,
    String message, {
    required Duration duration,
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        action: action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ==================== Error Handling Wrappers ====================

  /// Execute an async operation with automatic error handling.
  ///
  /// Wraps try-catch and displays error via snackbar if it occurs.
  /// Returns true if successful, false if error occurred.
  ///
  /// Example:
  /// ```dart
  /// final success = await ErrorHandler.handleAsync(
  ///   context,
  ///   operation: () async {
  ///     await saveData();
  ///   },
  ///   successMessage: 'Data tersimpan',
  /// );
  /// if (success) {
  ///   // Continue with next action
  /// }
  /// ```
  static Future<bool> handleAsync(
    BuildContext context, {
    required Future<void> Function() operation,
    String? successMessage,
    String? errorMessage,
    bool showSuccessSnackbar = false,
  }) async {
    try {
      await operation();

      if (showSuccessSnackbar && successMessage != null) {
        showSuccess(context, successMessage);
      }

      return true;
    } catch (e) {
      showError(context, e, customMessage: errorMessage);
      return false;
    }
  }

  /// Execute a sync operation with automatic error handling.
  ///
  /// Similar to handleAsync but for synchronous operations.
  static bool handleSync(
    BuildContext context, {
    required void Function() operation,
    String? successMessage,
    String? errorMessage,
    bool showSuccessSnackbar = false,
  }) {
    try {
      operation();

      if (showSuccessSnackbar && successMessage != null) {
        showSuccess(context, successMessage);
      }

      return true;
    } catch (e) {
      showError(context, e, customMessage: errorMessage);
      return false;
    }
  }
}
