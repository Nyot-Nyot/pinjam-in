import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_service.dart';

/// Provider untuk state management admin dashboard dan admin operations
///
/// Features:
/// - Dashboard statistics (users, items, storage)
/// - User growth data
/// - Recent activity logs
/// - Auto-refresh every 30 seconds
/// - Error handling with retry logic
class AdminProvider with ChangeNotifier {
  final dynamic _supabase;

  // State properties
  Map<String, dynamic>? _dashboardStats;
  List<Map<String, dynamic>> _userGrowth = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _topUsers = [];
  List<Map<String, dynamic>> _recentlyRegistered = [];
  List<Map<String, dynamic>> _inactiveUsers = [];
  Map<String, dynamic>? _itemStatistics;
  List<Map<String, dynamic>> _mostBorrowedItems = [];
  List<Map<String, dynamic>> _usersMostOverdue = [];
  List<Map<String, dynamic>> _itemGrowth = [];
  bool _isLoading = false;
  bool _isItemAnalyticsLoading = false;
  String? _itemAnalyticsError;
  String? _error;
  int _retryCount = 0;
  Timer? _autoRefreshTimer;

  // Getters
  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get userGrowth => _userGrowth;
  List<Map<String, dynamic>> get recentActivity => _recentActivity;
  List<Map<String, dynamic>> get topUsers => _topUsers;
  List<Map<String, dynamic>> get recentlyRegistered => _recentlyRegistered;
  List<Map<String, dynamic>> get inactiveUsers => _inactiveUsers;
  Map<String, dynamic>? get itemStatistics => _itemStatistics;
  List<Map<String, dynamic>> get mostBorrowedItems => _mostBorrowedItems;
  List<Map<String, dynamic>> get usersMostOverdue => _usersMostOverdue;
  List<Map<String, dynamic>> get itemGrowth => _itemGrowth;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isItemAnalyticsLoading => _isItemAnalyticsLoading;
  String? get itemAnalyticsError => _itemAnalyticsError;

  // Constants
  static const int maxRetryAttempts = 3;
  static const Duration autoRefreshInterval = Duration(seconds: 30);
  int _userGrowthDays = 30;
  int get userGrowthDays => _userGrowthDays;
  set userGrowthDays(int days) {
    if (days <= 0) return;
    _userGrowthDays = days;
  }

  static const int recentActivityLimit = 10;
  static const int topUsersLimit = 10;
  static const int recentlyRegisteredLimit = 5;
  static const int inactiveUsersLimit = 10;
  static const int mostBorrowedItemsLimit = 10;
  static const int usersMostOverdueLimit = 10;

  AdminProvider() : _supabase = Supabase.instance.client {
    // Load initial data
    loadDashboardStats();
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  /// Named constructor for tests that avoids initializing Supabase or starting
  /// the auto-refresh timer. Use this in widget tests to provide a stable,
  /// no-network provider instance.
  AdminProvider.noInit() : _supabase = null;

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

      // Fetch top users (non-fatal)
      List<dynamic> topUsersResponse = <dynamic>[];
      try {
        topUsersResponse = await _supabase.rpc(
          'admin_get_top_users',
          params: {'p_limit': topUsersLimit},
        );
      } catch (e) {
        debugPrint('AdminProvider: failed to fetch top users: $e');
        topUsersResponse = <dynamic>[];
      }

      // Parse responses
      final statsList = statsResponse as List;
      _dashboardStats = statsList.isNotEmpty
          ? statsList.first as Map<String, dynamic>
          : null;

      _userGrowth = (growthResponse as List).cast<Map<String, dynamic>>();

      _recentActivity = (activityResponse as List).cast<Map<String, dynamic>>();
      _topUsers = (topUsersResponse as List).cast<Map<String, dynamic>>();
      // Recently registered: use admin_get_all_users with limit
      try {
        final recentUsersResponse = await _supabase.rpc(
          'admin_get_all_users',
          params: {'p_limit': recentlyRegisteredLimit},
        );
        _recentlyRegistered = (recentUsersResponse as List)
            .cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint(
          'AdminProvider: failed to fetch recently registered users: $e',
        );
        _recentlyRegistered = [];
      }
      // Inactive users: use admin_get_all_users with status filter
      try {
        final inactiveUsersResponse = await _supabase.rpc(
          'admin_get_all_users',
          params: {
            'p_limit': inactiveUsersLimit,
            'p_status_filter': 'inactive',
          },
        );
        _inactiveUsers = (inactiveUsersResponse as List)
            .cast<Map<String, dynamic>>();
        // we'll fetch item-specific analytics in a dedicated method
      } catch (e) {
        debugPrint('AdminProvider: failed to fetch inactive users: $e');
        _inactiveUsers = [];
      }

      // Fetch item-specific analytics asynchronously and non-blocking
      try {
        await _fetchItemAnalytics();
      } catch (e) {
        debugPrint('AdminProvider: failed to fetch item analytics: $e');
      }

      _isLoading = false;
      _error = null;
      _retryCount = 0;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();

      // If the error suggests the missing server function (schema mismatch), stop auto-refresh
      final msg = _error?.toString() ?? '';
      if (msg.contains('PGRST202') ||
          msg.contains('Could not find the function') ||
          msg.contains('schema cache')) {
        debugPrint(
          'AdminProvider: detected schema-level error, disabling auto-refresh: $msg',
        );
        _stopAutoRefresh();
        notifyListeners();
        return;
      }

      // Retry logic for transient errors
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

  /// Fetch item-specific analytics data with its own loading/error state.
  Future<void> _fetchItemAnalytics() async {
    _isItemAnalyticsLoading = true;
    _itemAnalyticsError = null;
    notifyListeners();
    try {
      try {
        _itemStatistics = await AdminService.instance.getItemStatistics();
      } catch (e) {
        debugPrint('AdminProvider: item stats RPC error: $e');
        _itemStatistics = null;
      }

      try {
        _mostBorrowedItems = await AdminService.instance.getMostBorrowedItems(
          limit: mostBorrowedItemsLimit,
        );
      } catch (e) {
        debugPrint('AdminProvider: most borrowed RPC error: $e');
        _mostBorrowedItems = [];
      }

      try {
        _usersMostOverdue = await AdminService.instance.getUsersWithMostOverdue(
          limit: usersMostOverdueLimit,
        );
      } catch (e) {
        debugPrint('AdminProvider: users most overdue RPC error: $e');
        _usersMostOverdue = [];
      }

      try {
        _itemGrowth = await AdminService.instance.getItemGrowth(
          days: userGrowthDays,
        );
      } catch (e) {
        debugPrint('AdminProvider: item growth RPC error: $e');
        _itemGrowth = [];
      }

      _itemAnalyticsError = null;
    } catch (e) {
      _itemAnalyticsError = e.toString();
      debugPrint(
        'AdminProvider: _fetchItemAnalytics general error: $_itemAnalyticsError',
      );
    }
    _isItemAnalyticsLoading = false;
    notifyListeners();
  }
}
