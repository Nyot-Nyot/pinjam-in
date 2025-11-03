import '../repositories/loan_repository.dart';
import '../repositories/persistence_loan_repository.dart';
import '../services/persistence_service.dart';
import '../services/shared_prefs_persistence.dart';

/// Very small, manual service locator for this project. This avoids adding
/// a new dependency (like get_it) while still providing a single place to
/// obtain repository instances and swap persistence implementations.
class ServiceLocator {
  static PersistenceService _persistenceService = SharedPrefsPersistence();
  static LoanRepository _loanRepository = PersistenceLoanRepository(
    _persistenceService,
  );

  /// Initialize the locator with an optional custom persistence service.
  /// Call this early in app startup if you need a non-default implementation.
  static void init({PersistenceService? persistenceService}) {
    if (persistenceService != null) {
      _persistenceService = persistenceService;
    }
    _loanRepository = PersistenceLoanRepository(_persistenceService);
  }

  static LoanRepository get loanRepository => _loanRepository;

  static PersistenceService get persistenceService => _persistenceService;

  /// Replace the persistence service at runtime. Useful for switching between
  /// local and remote backends (e.g. after login). This also updates the
  /// repository instances so callers get the new implementation.
  static void setPersistenceService(PersistenceService service) {
    _persistenceService = service;
    _loanRepository = PersistenceLoanRepository(_persistenceService);
  }
}
