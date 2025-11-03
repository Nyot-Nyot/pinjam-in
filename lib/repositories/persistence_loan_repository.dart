import '../models/loan_item.dart';
import '../services/persistence_service.dart';
import 'loan_repository.dart';

/// Thin implementation of [LoanRepository] that delegates to a
/// [PersistenceService]. This allows providers to depend on the repository
/// abstraction while existing persistence implementations remain unchanged.
class PersistenceLoanRepository implements LoanRepository {
  final PersistenceService _service;

  PersistenceLoanRepository(this._service);

  @override
  Future<void> deleteItem(String itemId) => _service.deleteItem(itemId);

  @override
  Future<String?> currentUserId() => _service.currentUserId();

  @override
  Future<List<LoanItem>> loadActive() => _service.loadActive();

  @override
  Future<List<LoanItem>> loadHistory() => _service.loadHistory();

  @override
  Future<String?> uploadImage(String localPath, String itemId) =>
      _service.uploadImage(localPath, itemId);

  @override
  Future<void> saveActive(List<LoanItem> active) => _service.saveActive(active);

  @override
  Future<void> saveHistory(List<LoanItem> history) =>
      _service.saveHistory(history);

  @override
  Future<void> saveAll({
    required List<LoanItem> active,
    required List<LoanItem> history,
  }) => _service.saveAll(active: active, history: history);
}
