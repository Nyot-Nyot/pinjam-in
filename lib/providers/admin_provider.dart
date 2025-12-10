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
        // Item statistics: non-fatal
        try {
          final itemStatsResponse = await _supabase.rpc(
            'admin_get_item_statistics',
          );
          _itemStatistics = (itemStatsResponse as List).isNotEmpty
              ? (itemStatsResponse as List).first as Map<String, dynamic>
              : null;
        } catch (e) {
          debugPrint('AdminProvider: failed to fetch item statistics: $e');
          _itemStatistics = null;
        }

        // Most borrowed items: try server-side or compute fallback
        try {
          final mostBorrowedResponse = await _supabase.rpc(
            'admin_get_top_items',
            params: {'p_limit': mostBorrowedItemsLimit},
          );
          _mostBorrowedItems = (mostBorrowedResponse as List)
              .cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('AdminProvider: failed to fetch most borrowed items: $e');
          // fallback: compute client-side by loading recent items
          try {
            final itemsRes = await _supabase.rpc(
              'admin_get_all_items',
              params: {'p_limit': 1000},
            );
            final items = (itemsRes as List).cast<Map<String, dynamic>>();
            final counts = <String, Map<String, dynamic>>{};
            for (final it in items) {
              final key = (it['name'] ?? it['id'] ?? 'unknown').toString();
              if (!counts.containsKey(key)) {
                counts[key] = {'name': key, 'count': 1, 'sample_item': it};
              } else {
                counts[key]!['count'] = counts[key]!['count'] + 1;
              }
            }
            final arr = counts.values.toList()
              ..sort(
                (a, b) => (b['count'] as int).compareTo(a['count'] as int),
              );
            _mostBorrowedItems = arr
                .take(mostBorrowedItemsLimit)
                .map((e) => e.cast<String, dynamic>())
                .toList();
          } catch (e2) {
            debugPrint(
              'AdminProvider: fallback compute most borrowed items failed: $e2',
            );
            _mostBorrowedItems = [];
          }
        }

        // Users with most overdue items: prefer top users with overdue counts
        try {
          final res = await _supabase.rpc(
            'admin_get_top_users',
            params: {'p_limit': usersMostOverdueLimit * 2},
          );
          final list = (res as List).cast<Map<String, dynamic>>();
          list.sort(
            (a, b) => ((b['overdue_items'] ?? 0) as int).compareTo(
              (a['overdue_items'] ?? 0) as int,
            ),
          );
          _usersMostOverdue = list.take(usersMostOverdueLimit).toList();
        } catch (e) {
          debugPrint(
            'AdminProvider: failed to fetch users with most overdue: $e',
          );
          _usersMostOverdue = [];
        }

        // Item growth: non-fatal, try RPC admin_get_item_growth else compute
        try {
          final itemGrowthRpc = await _supabase.rpc(
            'admin_get_item_growth',
            params: {'p_days': userGrowthDays},
          );
          _itemGrowth = (itemGrowthRpc as List).cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('AdminProvider: failed to fetch item growth rpc: $e');
          // Fallback: compute using items list
          try {
            final itemsRes = await _supabase.rpc(
              'admin_get_all_items',
              params: {'p_limit': 5000},
            );
            final items = (itemsRes as List).cast<Map<String, dynamic>>();
            final now = DateTime.now();
            final start = now.subtract(Duration(days: userGrowthDays - 1));
            final counts = <String, int>{};
            for (int i = 0; i < userGrowthDays; i++) {
              final d = start.add(Duration(days: i));
              counts[d.toIso8601String().substring(0, 10)] = 0;
            }
            for (final it in items) {
              final createdStr = it['created_at']?.toString();
              if (createdStr == null) continue;
              final created = DateTime.tryParse(createdStr);
              if (created == null) continue;
              final key = created.toIso8601String().substring(0, 10);
              if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
            }
            _itemGrowth = counts.entries
                .map((e) => {'date': e.key, 'count': e.value})
                .toList();
          } catch (e2) {
            debugPrint(
              'AdminProvider: item growth fallback compute failed: $e2',
            );
            _itemGrowth = [];
          }
        }
      } catch (e) {
        debugPrint('AdminProvider: failed to fetch inactive users: $e');
        _inactiveUsers = [];
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
}
