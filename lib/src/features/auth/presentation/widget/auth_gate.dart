import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinjam_in/src/features/auth/data/provider/auth_provider.dart';
import 'package:pinjam_in/src/features/auth/presentation/screen/login_screen.dart';
import 'package:pinjam_in/src/features/home/presentation/screen/home_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
