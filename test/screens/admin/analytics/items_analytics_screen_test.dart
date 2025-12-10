import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/providers/admin_provider.dart';
import 'package:pinjam_in/screens/admin/analytics/items_analytics_screen.dart';
import 'package:provider/provider.dart';

class FakeAdminProviderForItems extends AdminProvider {
  final Map<String, dynamic>? _itemStats;
  final List<Map<String, dynamic>> _itemGrowth;
  final List<Map<String, dynamic>> _topItems;
  final List<Map<String, dynamic>> _usersMostOverdue;

  FakeAdminProviderForItems({
    Map<String, dynamic>? itemStats,
    List<Map<String, dynamic>>? itemGrowth,
    List<Map<String, dynamic>>? topItems,
    List<Map<String, dynamic>>? usersMostOverdue,
    bool isLoading = false,
    String? analyticsError,
  }) : _itemStats = itemStats,
       _itemGrowth = itemGrowth ?? [],
       _topItems = topItems ?? [],
       _usersMostOverdue = usersMostOverdue ?? [],
       _fakeLoading = isLoading,
       _fakeAnalyticsError = analyticsError,
       super.noInit();
  final bool _fakeLoading;
  final String? _fakeAnalyticsError;

  @override
  Map<String, dynamic>? get itemStatistics =>
      _itemStats ?? super.itemStatistics;

  @override
  List<Map<String, dynamic>> get itemGrowth =>
      _itemGrowth.isNotEmpty ? _itemGrowth : super.itemGrowth;

  @override
  List<Map<String, dynamic>> get mostBorrowedItems =>
      _topItems.isNotEmpty ? _topItems : super.mostBorrowedItems;

  @override
  List<Map<String, dynamic>> get usersMostOverdue =>
      _usersMostOverdue.isNotEmpty ? _usersMostOverdue : super.usersMostOverdue;

  @override
  Future<void> loadDashboardStats() async {}

  @override
  Future<void> refreshStats() async {}

  @override
  Future<void> retry() async {}

  @override
  bool get isItemAnalyticsLoading => _fakeLoading;

  @override
  String? get itemAnalyticsError => _fakeAnalyticsError;
}

void main() {
  testWidgets('ItemsAnalyticsScreen displays metrics, chart, and lists', (
    tester,
  ) async {
    final fake = FakeAdminProviderForItems(
      itemStats: {
        'total_items': 20,
        'borrowed_items': 5,
        'returned_items': 12,
        'overdue_items': 3,
        'returned_percentage': 60,
      },
      itemGrowth: List.generate(
        7,
        (i) => {'date': '2025-12-${i + 1}', 'count': i + 1},
      ),
      topItems: [
        {'name': 'Hammer', 'count': 5},
        {'name': 'Screwdriver', 'count': 4},
      ],
      usersMostOverdue: [
        {
          'full_name': 'Charlie',
          'email': 'charlie@example.com',
          'overdue_items': 2,
        },
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AdminProvider>(create: (_) => fake)],
        child: MaterialApp(
          home: Scaffold(
            body: ItemsAnalyticsScreen(wrapWithAdminLayout: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Items Analytics'), findsOneWidget);
    // Metrics
    expect(find.text('Key Metrics'), findsOneWidget);
    expect(find.text('Total Items'), findsOneWidget);
    // Chart
    expect(find.text('Items Created (last 7 days)'), findsOneWidget);
    // Top items
    expect(find.text('Most Borrowed Items'), findsOneWidget);
    expect(find.text('Hammer'), findsOneWidget);
    expect(find.text('Screwdriver'), findsOneWidget);
    // Users most overdue
    expect(find.text('Users with Most Overdue'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
  });

  testWidgets('ItemsAnalyticsScreen is responsive on narrow screens', (
    tester,
  ) async {
    final fake = FakeAdminProviderForItems(
      itemStats: {
        'total_items': 20,
        'borrowed_items': 5,
        'returned_items': 12,
        'overdue_items': 3,
        'returned_percentage': 60,
      },
      itemGrowth: List.generate(
        7,
        (i) => {'date': '2025-12-${i + 1}', 'count': i + 1},
      ),
      topItems: [
        {'name': 'Hammer', 'count': 5},
        {'name': 'Screwdriver', 'count': 4},
      ],
      usersMostOverdue: [
        {
          'full_name': 'Charlie',
          'email': 'charlie@example.com',
          'overdue_items': 2,
        },
      ],
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
        providers: [ChangeNotifierProvider<AdminProvider>(create: (_) => fake)],
        child: MaterialApp(
          home: Scaffold(
            body: ItemsAnalyticsScreen(wrapWithAdminLayout: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull);
    expect(find.text('Items Analytics'), findsOneWidget);
  });

  testWidgets('ItemsAnalyticsScreen shows loading state for item analytics', (
    tester,
  ) async {
    final fake = FakeAdminProviderForItems(isLoading: true);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AdminProvider>(create: (_) => fake)],
        child: MaterialApp(
          home: Scaffold(
            body: ItemsAnalyticsScreen(wrapWithAdminLayout: false),
          ),
        ),
      ),
    );
    await tester.pump();
    // Progress indicators should appear for metric sections
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('ItemsAnalyticsScreen shows error when item analytics fails', (
    tester,
  ) async {
    final fake = FakeAdminProviderForItems(analyticsError: 'boom');
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AdminProvider>(create: (_) => fake)],
        child: MaterialApp(
          home: Scaffold(
            body: ItemsAnalyticsScreen(wrapWithAdminLayout: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Failed to load item analytics'),
      findsOneWidget,
    );
  });
}
