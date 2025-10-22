import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/persistence_service.dart';
import '../services/shared_prefs_persistence.dart';
import '../services/supabase_persistence.dart';
import '../utils/logger.dart' as logger;

/// Provider untuk mengelola PersistenceService
///
/// Mengelola:
/// - Service initialization (SharedPrefs atau Supabase)
/// - Service switching (local <-> remote)
/// - Current service state
class PersistenceProvider with ChangeNotifier {
  PersistenceService? _service;
  bool _isInitialized = false;
  bool _isUsingSupabase = false;
  String? _errorMessage;

  // Getters
  PersistenceService? get service => _service;
  bool get isInitialized => _isInitialized;
  bool get isUsingSupabase => _isUsingSupabase;
  bool get isUsingLocal => !_isUsingSupabase && _service != null;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  PersistenceProvider() {
    _initializeDefaultService();
  }

  /// Initialize dengan service default (SharedPreferences)
  Future<void> _initializeDefaultService() async {
    try {
      logger.AppLogger.info(
        'Initializing default persistence service (SharedPrefs)...',
      );

      _service = SharedPrefsPersistence();
      _isUsingSupabase = false;
      _isInitialized = true;

      logger.AppLogger.success('SharedPrefs persistence initialized');
      notifyListeners();
    } catch (e) {
      logger.AppLogger.error('Failed to initialize default persistence', e);
      _errorMessage = 'Gagal menginisialisasi penyimpanan lokal';
      _isInitialized = true; // Mark as initialized even on error
      notifyListeners();
    }
  }

  /// Switch ke Supabase persistence
  ///
  /// Dipanggil setelah user berhasil login
  Future<bool> switchToSupabase() async {
    try {
      logger.AppLogger.info('Switching to Supabase persistence...');

      // Check if Supabase is initialized
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create Supabase persistence service
      final supabaseService = SupabasePersistence.fromClient(client);

      _service = supabaseService;
      _isUsingSupabase = true;
      _errorMessage = null;

      logger.AppLogger.success('Switched to Supabase persistence');
      notifyListeners();
      return true;
    } catch (e) {
      logger.AppLogger.error('Failed to switch to Supabase', e);
      _errorMessage = 'Gagal beralih ke penyimpanan remote';
      notifyListeners();
      return false;
    }
  }

  /// Switch ke local persistence (SharedPreferences)
  ///
  /// Dipanggil setelah user logout
  Future<bool> switchToLocal() async {
    try {
      logger.AppLogger.info('Switching to local persistence...');

      _service = SharedPrefsPersistence();
      _isUsingSupabase = false;
      _errorMessage = null;

      logger.AppLogger.success('Switched to local persistence');
      notifyListeners();
      return true;
    } catch (e) {
      logger.AppLogger.error('Failed to switch to local persistence', e);
      _errorMessage = 'Gagal beralih ke penyimpanan lokal';
      notifyListeners();
      return false;
    }
  }

  /// Migrate data dari local ke Supabase
  ///
  /// Dipanggil setelah login pertama kali untuk sync data lokal
  Future<bool> migrateLocalDataToSupabase() async {
    if (!_isUsingSupabase || _service is! SupabasePersistence) {
      logger.AppLogger.warning('Cannot migrate: Not using Supabase');
      return false;
    }

    try {
      logger.AppLogger.info('Migrating local data to Supabase...');

      // Load data dari local storage
      final localService = SharedPrefsPersistence();
      final activeLoans = await localService.loadActive();
      final historyLoans = await localService.loadHistory();

      if (activeLoans.isEmpty && historyLoans.isEmpty) {
        logger.AppLogger.info('No local data to migrate');
        return true;
      }

      // Save ke Supabase
      final supabaseService = _service as SupabasePersistence;
      await supabaseService.saveAll(active: activeLoans, history: historyLoans);

      logger.AppLogger.success(
        'Migrated ${activeLoans.length} active and ${historyLoans.length} history items to Supabase',
      );
      return true;
    } catch (e) {
      logger.AppLogger.error('Failed to migrate local data', e);
      _errorMessage = 'Gagal memigrasikan data lokal';
      notifyListeners();
      return false;
    }
  }

  /// Get current user ID (jika menggunakan Supabase)
  Future<String?> getCurrentUserId() async {
    if (_service == null) return null;
    return await _service!.currentUserId();
  }

  /// Clear error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Re-initialize service (untuk force refresh)
  Future<void> reinitialize() async {
    _isInitialized = false;
    _service = null;
    _errorMessage = null;
    notifyListeners();

    await _initializeDefaultService();
  }
}
