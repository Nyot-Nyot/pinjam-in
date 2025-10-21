import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinjam_in/src/features/auth/presentation/manager/auth_providers.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(authRepositoryProvider)
                    .signInWithEmail(
                      emailController.text,
                      passwordController.text,
                    );
              },
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(authRepositoryProvider)
                    .signUpWithEmail(
                      emailController.text,
                      passwordController.text,
                    );
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
