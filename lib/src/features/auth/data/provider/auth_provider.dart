import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinjam_in/src/features/auth/data/repository/auth_repository_impl.dart';
import 'package:pinjam_in/src/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider for SupabaseClient
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(supabaseClient);
});

// Provider for Auth State Changes
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});
