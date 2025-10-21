import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Future<User?> getCurrentUser();
  Future<void> signUp(String email, String password);
  Future<void> signInWithEmail(String email, String password);
  Future<void> signOut();
  Stream<User?> get authStateChanges;
}
