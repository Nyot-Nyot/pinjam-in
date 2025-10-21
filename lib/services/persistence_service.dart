import '../models/loan_item.dart';

/// Minimal persistence abstraction used by the app.
/// Implementations can use local storage (SharedPreferences), Firestore, etc.
abstract class PersistenceService {
  Future<List<LoanItem>> loadActive();
  Future<List<LoanItem>> loadHistory();

  Future<void> saveActive(List<LoanItem> active);
  Future<void> saveHistory(List<LoanItem> history);

  /// Convenience: save both lists. Implementations may override for efficiency.
  Future<void> saveAll({
    required List<LoanItem> active,
    required List<LoanItem> history,
  }) async {
    await Future.wait([saveActive(active), saveHistory(history)]);
  }

  /// Optional image upload helper for persistence backends that support
  /// remote storage (e.g. Supabase Storage). Implementations that don't
  /// support uploads can return null.
  Future<String?> uploadImage(String localPath, String itemId) async => null;

  /// Optional: return the currently-authenticated user's id when the
  /// persistence backend supports authentication (e.g. Supabase).
  /// Default implementations return null.
  Future<String?> currentUserId() async => null;
}
