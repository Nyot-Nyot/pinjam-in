import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/providers/admin_provider.dart';
import 'package:pinjam_in/screens/admin/analytics/user_analytics_screen.dart';
import 'package:provider/provider.dart';

class FakeAdminProvider extends AdminProvider {
  final Map<String, dynamic>? _dashboardStats;
  final List<Map<String, dynamic>> _userGrowth;
  final List<Map<String, dynamic>> _topUsers;
  FakeAdminProvider({
    Map<String, dynamic>? dashboardStats,
    List<Map<String, dynamic>>? userGrowth,
    List<Map<String, dynamic>>? topUsers,
  }) : _dashboardStats = dashboardStats,
       _userGrowth = userGrowth ?? [],
       _topUsers = topUsers ?? [],
       super.noInit();

  @override
  Map<String, dynamic>? get dashboardStats =>
      _dashboardStats ?? super.dashboardStats;

  @override
  List<Map<String, dynamic>> get userGrowth =>
      _userGrowth.isNotEmpty ? _userGrowth : super.userGrowth;

  @override
  List<Map<String, dynamic>> get topUsers =>
      _topUsers.isNotEmpty ? _topUsers : super.topUsers;

  @override
  Future<void> loadDashboardStats() async {}

  @override
  Future<void> refreshStats() async {}

  @override
  Future<void> retry() async {}
}

void main() {
  testWidgets('UserAnalyticsScreen renders metrics and chart', (tester) async {
    final fakeProvider = FakeAdminProvider(
      dashboardStats: {
        'total_users': 123,
        'active_users': 100,
        'inactive_users': 23,
        'new_users_today': 2,
      },
      userGrowth: List.generate(
        7,
        (i) => {'date': '2025-12-${i + 1}', 'new_users': i + 1},
      ),
      topUsers: [
        {'full_name': 'Alice', 'email': 'alice@example.com', 'total_items': 12},
        {'full_name': 'Bob', 'email': 'bob@example.com', 'total_items': 10},
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminProvider>(create: (_) => fakeProvider),
        ],
        child: MaterialApp(
          home: Scaffold(body: UserAnalyticsScreen(wrapWithAdminLayout: false)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('User Analytics'), findsOneWidget);
    expect(find.text('Key Metrics'), findsOneWidget);
    expect(find.text('Top Active Users'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('UserAnalyticsScreen is responsive on narrow screens', (
    tester,
  ) async {
    final fakeProvider = FakeAdminProvider(
      dashboardStats: {
        'total_users': 10,
        'active_users': 8,
        'inactive_users': 2,
        'new_users_today': 1,
      },
      userGrowth: List.generate(
        7,
        (i) => {'date': '2025-12-${i + 1}', 'new_users': i + 1},
      ),
    );

    // Set narrow screen size
    tester.binding.window.physicalSizeTestValue = const Size(320, 800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AdminProvider>(create: (_) => fakeProvider),
        ],
        child: MaterialApp(
          home: Scaffold(body: UserAnalyticsScreen(wrapWithAdminLayout: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No render overflow exceptions are thrown
    final exception = tester.takeException();
    expect(exception, isNull);
    expect(find.text('User Analytics'), findsOneWidget);
  });
}
