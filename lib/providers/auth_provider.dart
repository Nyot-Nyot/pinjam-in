import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart' as logger;

/// Provider untuk mengelola state dan operasi authentikasi
///
/// Mengelola:
/// - Auth state (user, session)
/// - Login/logout/register operations
/// - Loading dan error states
class AuthProvider with ChangeNotifier {
  // State
  User? _user;
  Session? _session;
  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // Getters
  User? get user => _user;
  Session? get session => _session;
  UserProfile? get profile => _profile;
  String? get role => _profile?.role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isInitialized => _isInitialized;

  /// Check apakah user adalah admin
  bool get isAdmin => _profile?.role == 'admin';

  /// Check apakah user sudah login
  bool get isAuthenticated => _user != null && _session != null;

  /// Get user ID (jika ada)
  String? get userId => _user?.id;

  /// Get user email (jika ada)
  String? get userEmail => _user?.email;

  AuthProvider() {
    _initialize();
  }

  /// Initialize auth state dari Supabase
  Future<void> _initialize() async {
    try {
      logger.AppLogger.info('Initializing auth provider...');

      // Check current session
      final client = Supabase.instance.client;
      _session = client.auth.currentSession;
      _user = client.auth.currentUser;
      // If there's an active user, load profile (role)
      if (_user != null) {
        try {
          await loadProfile();
        } catch (_) {}
      }

      logger.AppLogger.info(
        'Auth initialized: ${_user != null ? "logged in as ${_user!.email}" : "not logged in"}',
      );

      // Listen to auth state changes
      client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        logger.AppLogger.info('Auth state changed: $event');

        _session = data.session;
        _user = _session?.user;
        // Load or clear profile depending on auth state
        if (_user != null) {
          try {
            await loadProfile();
          } catch (_) {
            _profile = null;
          }
        } else {
          _profile = null;
        }
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      logger.AppLogger.error('Failed to initialize auth', e);
      _isInitialized = true; // Mark as initialized even on error
      notifyListeners();
    }
  }

  /// Login dengan email dan password
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Attempting login for: $email');

      final client = Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      _session = response.session;
      _user = response.user;

      // Load profile for the authenticated user
      if (_user != null) {
        try {
          await loadProfile();
        } catch (_) {}
      }

      if (_user == null) {
        throw Exception('Login failed: No user returned');
      }

      logger.AppLogger.success('Login successful: ${_user!.email}');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Login gagal', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Register user baru
  Future<bool> register(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Attempting registration for: $email');

      final client = Supabase.instance.client;
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      // Note: Supabase might require email confirmation
      _session = response.session;
      _user = response.user;

      // Attempt to load profile if available
      if (_user != null) {
        try {
          await loadProfile();
        } catch (_) {}
      }

      if (_user == null) {
        throw Exception('Registration failed: No user returned');
      }

      logger.AppLogger.success('Registration successful: ${_user!.email}');

      // Check if email confirmation is required
      if (_session == null) {
        _errorMessage =
            'Registrasi berhasil! Silakan cek email untuk konfirmasi.';
        logger.AppLogger.info('Email confirmation required');
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Registrasi gagal', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout user
  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Logging out user: ${_user?.email}');

      final client = Supabase.instance.client;
      await client.auth.signOut();

      _user = null;
      _profile = null;
      _session = null;

      logger.AppLogger.success('Logout successful');
      notifyListeners();
    } catch (e, stackTrace) {
      _handleError('Logout gagal', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password (kirim email reset)
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Sending password reset email to: $email');

      final client = Supabase.instance.client;
      await client.auth.resetPasswordForEmail(email.trim());

      logger.AppLogger.success('Password reset email sent');
      _errorMessage =
          'Email reset password telah dikirim. Silakan cek inbox Anda.';
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Gagal mengirim email reset', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user profile (email atau password)
  Future<bool> updateProfile({String? newEmail, String? newPassword}) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Updating user profile...');

      final client = Supabase.instance.client;

      final attributes = <String, dynamic>{};
      if (newEmail != null) attributes['email'] = newEmail.trim();
      if (newPassword != null) attributes['password'] = newPassword;

      final response = await client.auth.updateUser(
        UserAttributes(email: newEmail?.trim(), password: newPassword),
      );

      _user = response.user;

      logger.AppLogger.success('Profile updated successfully');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Gagal memperbarui profil', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh session jika expired
  Future<void> refreshSession() async {
    try {
      logger.AppLogger.info('Refreshing session...');

      final client = Supabase.instance.client;
      final response = await client.auth.refreshSession();

      _session = response.session;
      _user = response.user;
      if (_user != null) {
        try {
          await loadProfile();
        } catch (_) {}
      }

      logger.AppLogger.success('Session refreshed');
      notifyListeners();
    } catch (e) {
      logger.AppLogger.error('Failed to refresh session', e);
      // Don't throw, just log
    }
  }

  /// Clear error message
  void clearError() {
    _clearError();
  }

  /// Check apakah user memiliki permission tertentu
  ///
  /// Untuk saat ini, admin memiliki semua permission.
  /// Di masa depan, bisa diperluas dengan permission granular.
  ///
  /// Contoh permission: 'users:read', 'users:write', 'items:delete', dll
  bool hasPermission(String permission) {
    // Admin memiliki semua permission
    if (isAdmin) return true;

    // User biasa tidak punya permission admin
    // TODO: Implementasi permission granular jika diperlukan
    return false;
  }

  /// Load the current user's profile (from public.profiles)
  Future<void> loadProfile() async {
    if (_user == null) return;
    try {
      final client = Supabase.instance.client;
      // select single profile row for current user
      final res = await client
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      if (res == null) {
        _profile = null;
      } else {
        try {
          final map = Map<String, dynamic>.from(res as Map);
          _profile = UserProfile.fromMap(map);
        } catch (_) {
          _profile = null;
        }
      }
      notifyListeners();
    } catch (e) {
      logger.AppLogger.error('Failed to load profile', e);
    }
  }

  // Private helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _handleError(String userMessage, Object error, StackTrace stackTrace) {
    _errorMessage = ErrorHandler.getFriendlyMessage(error);
    logger.AppLogger.error('$userMessage: $error', error);
    notifyListeners();
  }
}
