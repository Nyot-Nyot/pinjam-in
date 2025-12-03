import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants/storage_keys.dart';
import 'providers/admin_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/persistence_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/users/create_user_screen.dart';
import 'screens/admin/users/edit_user_screen.dart';
import 'screens/admin/users/user_detail_screen.dart';
import 'screens/admin/users/users_list_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/unauthorized_screen.dart';
import 'theme/app_theme.dart';
import 'utils/admin_guard.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // load optional .env from project root
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  // Debug: show whether dotenv loaded expected keys (visible in flutter run logs)
  try {
    final u = dotenv.env[StorageKeys.envSupabaseUrl];
    final k = dotenv.env[StorageKeys.envSupabaseAnonKey];
    AppLogger.debug(
      'SUPABASE_URL present: ${u != null && u.isNotEmpty}',
      'dotenv',
    );
    AppLogger.debug(
      'SUPABASE_ANON_KEY present: ${k != null && k.isNotEmpty}',
      'dotenv',
    );
  } catch (_) {}
  // Try to initialize Supabase once at startup if dotenv provides credentials.
  try {
    final url = dotenv.env[StorageKeys.envSupabaseUrl] ?? '';
    final key = dotenv.env[StorageKeys.envSupabaseAnonKey] ?? '';
    if (url.isNotEmpty && key.isNotEmpty) {
      try {
        // Supabase.initialize may throw if already initialized; ignore that case.
        // Session persistence is enabled by default in supabase_flutter
        await Supabase.initialize(url: url, anonKey: key);
        AppLogger.success('initialized from main.dart', 'supabase');
      } catch (e) {
        final s = e.toString();
        if (s.contains('already initialized') ||
            s.contains('this instance is already initialized') ||
            s.contains('already been initialized')) {
          // already initialized elsewhere, ignore
          AppLogger.info('already initialized earlier', 'supabase');
        } else {
          AppLogger.error('initialize error', e, 'supabase');
        }
      }
    } else {
      AppLogger.warning(
        'credentials missing in dotenv, skipping init in main',
        'supabase',
      );
    }
  } catch (_) {}
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. PersistenceProvider - Initialize first (mengelola storage service)
        ChangeNotifierProvider(create: (_) => PersistenceProvider()),

        // 2. AuthProvider - Independent dari persistence
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // 3. ThemeProvider - Independent, manages app theme
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // 4. AdminProvider - Independent, manages admin dashboard state
        ChangeNotifierProvider(create: (_) => AdminProvider()),

        // 5. LoanProvider - Depends on PersistenceProvider
        ChangeNotifierProxyProvider<PersistenceProvider, LoanProvider?>(
          create: (context) => null,
          update: (context, persistenceProvider, previous) {
            // If no persistence service yet, keep previous
            if (persistenceProvider.service == null) return previous;

            // Always create a fresh LoanProvider when persistence service is provided.
            // This ensures LoanProvider uses the current backend (SharedPrefs or Supabase).
            AppLogger.info(
              'Creating/refreshing LoanProvider with persistence service',
            );
            final loanProvider = LoanProvider(persistenceProvider.service!);
            // Defer heavy data loading until after first frame so app can render
            // initial UI without being blocked by storage parsing.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loanProvider.loadAllData();
            });
            return loanProvider;
          },
        ),
      ],
      child: const _MaterialAppWrapper(),
    );
  }
}

/// Wrapper widget to access providers in MaterialApp
class _MaterialAppWrapper extends StatelessWidget {
  const _MaterialAppWrapper();

  /// Route helper for admin screens
  Widget _getAdminScreen(String route) {
    // Handle user edit route with ID parameter
    if (route.startsWith('/admin/users/') && route.endsWith('/edit')) {
      final parts = route.split('/');
      if (parts.length >= 4) {
        final userId =
            parts[3]; // Extract userId from /admin/users/:userId/edit
        return EditUserScreen(userId: userId);
      }
    }

    // Handle user detail route with ID parameter
    if (route.startsWith('/admin/users/') &&
        route != '/admin/users' &&
        route != '/admin/users/create') {
      final userId = route.split('/').last;
      return UserDetailScreen(userId: userId);
    }

    switch (route) {
      case '/admin':
      case '/admin/dashboard':
        return const AdminDashboardScreen();
      case '/admin/users':
        return const UsersListScreen();
      case '/admin/users/create':
        return const CreateUserScreen();
      case '/admin/items':
        return const UnauthorizedScreen(); // Placeholder
      case '/admin/storage':
        return const UnauthorizedScreen(); // Placeholder
      case '/admin/analytics':
        return const UnauthorizedScreen(); // Placeholder
      case '/admin/audit':
        return const UnauthorizedScreen(); // Placeholder
      default:
        return const AdminDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinjam In',
      debugShowCheckedModeBanner: false,
      themeMode: context.watch<ThemeProvider>().themeMode,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        primaryColor: AppTheme.primaryPurple,
        scaffoldBackgroundColor: AppTheme.backgroundLight,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AppTheme.primaryPurple,
          secondary: AppTheme.primaryPurpleLight,
          surface: AppTheme.backgroundWhite,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppTheme.backgroundWhite,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.deepPurple,
        primaryColor: AppTheme.primaryPurple,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.primaryPurple,
          secondary: AppTheme.primaryPurpleLight,
          surface: const Color(0xFF2A2A2A),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF2A2A2A),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        // Admin routes with guard protection
        if (settings.name?.startsWith('/admin') ?? false) {
          return MaterialPageRoute(
            builder: (context) =>
                AdminGuardWidget(child: _getAdminScreen(settings.name!)),
            settings: settings,
          );
        }

        // Handle other routes (to be added later)
        return null;
      },
    );
  }
}
