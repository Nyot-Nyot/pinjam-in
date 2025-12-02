import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider untuk state management admin dashboard dan admin operations
///
/// Features:
/// - Dashboard statistics (users, items, storage)
/// - User growth data
/// - Recent activity logs
/// - Auto-refresh every 30 seconds
/// - Error handling with retry logic
class AdminProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // State properties
  Map<String, dynamic>? _dashboardStats;
  List<Map<String, dynamic>> _userGrowth = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = false;
  String? _error;
  int _retryCount = 0;
  Timer? _autoRefreshTimer;

  // Getters
  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get userGrowth => _userGrowth;
  List<Map<String, dynamic>> get recentActivity => _recentActivity;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constants
  static const int maxRetryAttempts = 3;
  static const Duration autoRefreshInterval = Duration(seconds: 30);
  static const int userGrowthDays = 30;
  static const int recentActivityLimit = 10;

  AdminProvider() {
    // Load initial data
    loadDashboardStats();
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  /// Load all dashboard data
  Future<void> loadDashboardStats() async {
    _isLoading = true;
    _error = null;
    _retryCount = 0;
    notifyListeners();

    await _fetchDashboardData();
  }

  /// Refresh dashboard data manually
  Future<void> refreshStats() async {
    _error = null;
    _retryCount = 0;
    notifyListeners();

    await _fetchDashboardData();
  }

  /// Internal method to fetch dashboard data with retry logic
  Future<void> _fetchDashboardData() async {
    try {
      // Fetch dashboard stats
      final statsResponse = await _supabase.rpc('admin_get_dashboard_stats');

      // Fetch user growth data
      final growthResponse = await _supabase.rpc(
        'admin_get_user_growth',
        params: {'p_days': userGrowthDays},
      );

      // Fetch recent activity
      final activityResponse = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(recentActivityLimit);

      // Parse responses
      final statsList = statsResponse as List;
      _dashboardStats = statsList.isNotEmpty
          ? statsList.first as Map<String, dynamic>
          : null;

      _userGrowth = (growthResponse as List).cast<Map<String, dynamic>>();

      _recentActivity = (activityResponse as List).cast<Map<String, dynamic>>();

      _isLoading = false;
      _error = null;
      _retryCount = 0;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();

      // Retry logic
      if (_retryCount < maxRetryAttempts) {
        _retryCount++;
        debugPrint(
          'AdminProvider: Retry attempt $_retryCount of $maxRetryAttempts',
        );

        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: _retryCount * 2));

        // Retry fetch
        await _fetchDashboardData();
      } else {
        debugPrint('AdminProvider: Max retry attempts reached. Error: $_error');
        notifyListeners();
      }
    }
  }

  /// Start auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(autoRefreshInterval, (_) {
      debugPrint('AdminProvider: Auto-refreshing dashboard stats...');
      refreshStats();
    });
  }

  /// Stop auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Manually retry after error
  Future<void> retry() async {
    _retryCount = 0;
    await loadDashboardStats();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }
}
