import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabaseClient;

  AuthRepositoryImpl(this._supabaseClient);

  @override
  Stream<User?> get authStateChanges => _supabaseClient.auth.onAuthStateChange
      .map((authState) => authState.session?.user);

  @override
  Future<User?> getCurrentUser() async {
    return _supabaseClient.auth.currentUser;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to sign in: ${e.message}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to sign out: $e');
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    try {
      await _supabaseClient.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to sign up: ${e.message}');
    }
  }
}
