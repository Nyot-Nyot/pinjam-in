import '../models/loan_item.dart';

/// Repository abstraction for loan data operations.
///
/// This sits above the persistence implementations and provides a stable
/// interface for the rest of the app (providers, use-cases, UI) to depend on.
abstract class LoanRepository {
  Future<List<LoanItem>> loadActive();

  Future<List<LoanItem>> loadHistory();

  Future<void> saveActive(List<LoanItem> active);

  Future<void> saveHistory(List<LoanItem> history);

  Future<void> saveAll({
    required List<LoanItem> active,
    required List<LoanItem> history,
  });

  Future<String?> uploadImage(String localPath, String itemId);

  Future<String?> currentUserId();

  Future<void> deleteItem(String itemId);
}
