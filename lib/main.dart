import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // load optional .env from project root
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  // Debug: show whether dotenv loaded expected keys (visible in flutter run logs)
  try {
    final u = dotenv.env['SUPABASE_URL'];
    final k = dotenv.env['SUPABASE_ANON_KEY'];
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
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
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
    return MaterialApp(
      title: 'Pinjam In',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const SplashScreen(),
    );
  }
}
