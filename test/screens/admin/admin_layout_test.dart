import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/models/user_profile.dart';
import 'package:pinjam_in/providers/auth_provider.dart';
import 'package:pinjam_in/providers/theme_provider.dart';
import 'package:pinjam_in/screens/admin/admin_layout.dart';
import 'package:pinjam_in/widgets/admin/breadcrumbs.dart';
import 'package:provider/provider.dart';

// Mock AuthProvider for testing
class MockAuthProvider extends AuthProvider {
  bool _mockIsAdmin = true;
  UserProfile? _mockProfile;
  bool _mockIsAuthenticated = true;

  @override
  bool get isAdmin => _mockIsAdmin;

  @override
  UserProfile? get profile => _mockProfile;

  @override
  String? get userEmail => 'admin@test.com';

  @override
  bool get isAuthenticated => _mockIsAuthenticated;

  void setAdmin(bool isAdmin) {
    _mockIsAdmin = isAdmin;
    notifyListeners();
  }

  void setAuthenticated(bool authenticated) {
    _mockIsAuthenticated = authenticated;
    notifyListeners();
  }

  void setProfile(UserProfile? profile) {
    _mockProfile = profile;
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    // Mock logout
  }
}

void main() {
  group('AdminLayout Tests', () {
    late MockAuthProvider mockAuthProvider;
    late ThemeProvider themeProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      mockAuthProvider.setProfile(
        const UserProfile(id: 'test-id', fullName: 'Admin User', role: 'admin'),
      );
      themeProvider = ThemeProvider();
    });

    Widget createTestWidget({
      required Widget child,
      String currentRoute = '/admin',
      List<BreadcrumbItem>? breadcrumbs,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: MaterialApp(
          home: AdminLayout(
            currentRoute: currentRoute,
            breadcrumbs: breadcrumbs,
            child: child,
          ),
        ),
      );
    }

    testWidgets('should display app bar with title', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Text('Content')));

      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('should display navigation menu items', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Text('Content')));

      // Open drawer on mobile
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);
    });

    testWidgets('should display user profile in menu', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Text('Content')));

      // Find and tap user profile avatar
      final avatarFinder = find.byType(CircleAvatar).last;
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(find.text('Admin User'), findsOneWidget);
      expect(find.text('admin@test.com'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('should display breadcrumbs when provided', (tester) async {
      final breadcrumbs = [
        BreadcrumbItem(label: 'Home', onTap: () {}),
        BreadcrumbItem(label: 'Admin', onTap: () {}),
        const BreadcrumbItem(label: 'Users'),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: const Text('Content'),
          breadcrumbs: breadcrumbs,
        ),
      );

      final bc = find.byType(Breadcrumbs);
      expect(
        find.descendant(of: bc, matching: find.text('Home')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bc, matching: find.text('Admin')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bc, matching: find.text('Users')),
        findsOneWidget,
      );
    });

    testWidgets('should display theme toggle button', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const Text('Content')));

      // Find theme toggle button
      final themeToggleButton = find.byIcon(Icons.dark_mode);
      expect(themeToggleButton, findsOneWidget);
    });

    testWidgets('should render child content', (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const Text('Test Content')),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('should highlight current route in navigation', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          currentRoute: '/admin/users',
          child: const Text('Content'),
        ),
      );

      // Open drawer
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      // Check that Users menu item is highlighted
      final usersListTile = find.ancestor(
        of: find.text('Users'),
        matching: find.byType(ListTile),
      );

      expect(usersListTile, findsOneWidget);
    });
  });

  group('Breadcrumbs Widget Tests', () {
    testWidgets('should display all breadcrumb items', (tester) async {
      final items = [
        const BreadcrumbItem(label: 'Home'),
        const BreadcrumbItem(label: 'Admin'),
        const BreadcrumbItem(label: 'Users'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Breadcrumbs(items: items)),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
    });

    testWidgets('should display chevron separators', (tester) async {
      final items = [
        const BreadcrumbItem(label: 'Home'),
        const BreadcrumbItem(label: 'Admin'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Breadcrumbs(items: items)),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('should handle breadcrumb item tap', (tester) async {
      bool tapped = false;

      final items = [
        BreadcrumbItem(label: 'Home', onTap: () => tapped = true),
        const BreadcrumbItem(label: 'Current'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Breadcrumbs(items: items)),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('ThemeProvider Tests', () {
    test('should initialize with system theme', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('should toggle theme between light and dark', () async {
      final provider = ThemeProvider();

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isLight, isTrue);
      expect(provider.isDark, isFalse);

      await provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDark, isTrue);
      expect(provider.isLight, isFalse);

      await provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);
    });
  });
}
