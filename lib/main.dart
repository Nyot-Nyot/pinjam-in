import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

// Compile-time toggle to control whether the app should wire to the local
// Firebase Emulator Suite. Use `--dart-define=USE_EMULATOR=false` to disable.
const bool kUseEmulator = bool.fromEnvironment(
  'USE_EMULATOR',
  defaultValue: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Try to initialize Firebase on all platforms. Some desktop builds may not
  // have firebase_core platform support; we catch and continue so the app
  // doesn't crash. When initialization succeeds and we're in debug, point
  // SDKs at the local emulator suite.
  try {
    await Firebase.initializeApp();

    if (kDebugMode && kUseEmulator) {
      // On Android emulator the host machine is reachable at 10.0.2.2.
      // Otherwise the host is localhost for web and desktop development.
      final emulatorHost = defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';

      try {
        FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
        FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
        FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
        // Helpful debug print so developers can see emulator wiring in logs.
        debugPrint('Firebase emulators configured: $emulatorHost');
        // In debug + emulator mode, ensure a test user exists and is signed in
        // so the developer can open the app without manual seeding.
        if (Firebase.apps.isNotEmpty) {
          await _ensureDevAuthUser();
        }
      } catch (e) {
        // If emulator wiring fails (uncommon), don't block app startup.
        debugPrint('Failed to configure Firebase emulators: $e');
      }
    }
  } catch (e) {
    debugPrint('Firebase.initializeApp() failed: $e');
    // Continue without Firebase; login/register will fall back to local
    // SharedPrefsPersistence when Firebase isn't available.
  }

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

/// Create or sign-in a short-lived dev test user when running against the
/// emulator. This is executed only in debug mode and helps keep the app
/// usable without manual seeding.
Future<void> _ensureDevAuthUser() async {
  try {
    final auth = FirebaseAuth.instance;
    const email = 'test@example.com';
    const password = 'password123';

    try {
      // First try to sign in if the user already exists.
      await auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint('Dev user signed in');
    } catch (_) {
      try {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('Dev user created: ${cred.user?.uid}');
      } catch (e) {
        // If the user already exists or creation failed, try signing in again.
        try {
          await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          debugPrint('Dev user signed in after create fallback');
        } catch (e2) {
          debugPrint('Failed to create or sign-in dev user: $e2');
        }
      }
    }

    // Populate a users doc for the current user so Firestore-backed UI sees a
    // corresponding document. Use the auth UID as the doc id if available.
    final user = auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': 'Dev Tester',
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Dev user document written: $uid');
    }
  } catch (e) {
    debugPrint('Dev user bootstrap failed: $e');
  }
}
