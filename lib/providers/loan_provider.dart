import 'package:flutter/foundation.dart';

import '../models/loan_item.dart';
import '../services/persistence_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart' as logger;

/// Provider untuk mengelola state dan operasi loan items
///
/// Mengelola:
/// - List active loans dan history
/// - Loading states
/// - Error handling
/// - CRUD operations (Create, Read, Update, Delete)
class LoanProvider with ChangeNotifier {
  final PersistenceService _persistenceService;

  // State
  List<LoanItem> _activeLoans = [];
  List<LoanItem> _historyLoans = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<LoanItem> get activeLoans => _activeLoans;
  List<LoanItem> get historyLoans => _historyLoans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  // Computed getters
  int get activeLoanCount => _activeLoans.length;
  int get historyLoanCount => _historyLoans.length;

  /// Mendapatkan jumlah item yang overdue (terlambat)
  int get overdueCount {
    final now = DateTime.now();
    return _activeLoans.where((loan) {
      if (loan.dueDate == null) return false;
      return loan.dueDate!.isBefore(now);
    }).length;
  }

  LoanProvider(this._persistenceService);

  /// Load semua data (active + history)
  Future<void> loadAllData() async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Loading all loan data...');

      final results = await Future.wait([
        _persistenceService.loadActive(),
        _persistenceService.loadHistory(),
      ]);

      _activeLoans = results[0];
      _historyLoans = results[1];

      logger.AppLogger.info(
        'Loaded ${_activeLoans.length} active loans and ${_historyLoans.length} history items',
      );
      notifyListeners();
    } catch (e, stackTrace) {
      _handleError('Gagal memuat data', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Load hanya active loans
  Future<void> loadActiveLoans() async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Loading active loans...');
      _activeLoans = await _persistenceService.loadActive();
      logger.AppLogger.info('Loaded ${_activeLoans.length} active loans');
      notifyListeners();
    } catch (e, stackTrace) {
      _handleError('Gagal memuat data aktif', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Load hanya history loans
  Future<void> loadHistoryLoans() async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Loading history loans...');
      _historyLoans = await _persistenceService.loadHistory();
      logger.AppLogger.info('Loaded ${_historyLoans.length} history items');
      notifyListeners();
    } catch (e, stackTrace) {
      _handleError('Gagal memuat riwayat', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Tambah loan baru
  Future<bool> addLoan(LoanItem loan) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Adding new loan: ${loan.title}');

      _activeLoans.add(loan);
      await _persistenceService.saveActive(_activeLoans);
      // Ensure backend caches are invalidated for this item
      try {
        await _persistenceService.invalidateCache(itemId: loan.id);
      } catch (_) {}

      logger.AppLogger.success('Loan added successfully');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Gagal menambahkan data', e, stackTrace);
      // Rollback
      _activeLoans.removeWhere((item) => item.id == loan.id);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update loan yang sudah ada
  Future<bool> updateLoan(LoanItem updatedLoan) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Updating loan: ${updatedLoan.title}');

      // Simpan nilai lama untuk rollback
      final oldIndex = _activeLoans.indexWhere(
        (item) => item.id == updatedLoan.id,
      );

      if (oldIndex == -1) {
        throw Exception('Loan tidak ditemukan');
      }

      _activeLoans[oldIndex] = updatedLoan;
      await _persistenceService.saveActive(_activeLoans);
      // Ensure backend caches are invalidated for this updated item
      try {
        await _persistenceService.invalidateCache(itemId: updatedLoan.id);
      } catch (_) {}

      logger.AppLogger.success('Loan updated successfully');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Gagal memperbarui data', e, stackTrace);
      // Rollback jika ada
      await loadActiveLoans(); // Reload dari storage
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Pindahkan loan dari active ke history (mark as returned)
  Future<bool> markAsReturned(String loanId, DateTime returnedDate) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Marking loan as returned: $loanId');

      // Cari loan di active
      final loanIndex = _activeLoans.indexWhere((item) => item.id == loanId);
      if (loanIndex == -1) {
        throw Exception('Loan tidak ditemukan');
      }

      final loan = _activeLoans[loanIndex];
      final updatedLoan = loan.copyWith(
        returnedAt: returnedDate,
        status: 'returned',
      );

      // Pindahkan ke history
      _activeLoans.removeAt(loanIndex);
      _historyLoans.insert(0, updatedLoan); // Insert di awal

      // Save ke persistence
      await _persistenceService.saveAll(
        active: _activeLoans,
        history: _historyLoans,
      );
      // Invalidate cache for the moved item
      try {
        await _persistenceService.invalidateCache(itemId: updatedLoan.id);
      } catch (_) {}

      logger.AppLogger.success('Loan marked as returned');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Gagal menandai sebagai dikembalikan', e, stackTrace);
      // Rollback
      await loadAllData();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete loan permanently
  Future<bool> deleteLoan(String loanId) async {
    _setLoading(true);
    _clearError();

    try {
      logger.AppLogger.info('Deleting loan: $loanId');

      // Cek apakah loan ada
      final existsInActive = _activeLoans.any((item) => item.id == loanId);
      final existsInHistory = _historyLoans.any((item) => item.id == loanId);

      if (!existsInActive && !existsInHistory) {
        throw Exception('Loan tidak ditemukan');
      }

      // Hapus dari active atau history
      _activeLoans.removeWhere((item) => item.id == loanId);
      _historyLoans.removeWhere((item) => item.id == loanId);

      // Delete dari persistence backend
      await _persistenceService.deleteItem(loanId);

      // Save updated lists
      await _persistenceService.saveAll(
        active: _activeLoans,
        history: _historyLoans,
      );
      // Ensure caches are invalidated for the deleted item
      try {
        await _persistenceService.invalidateCache(itemId: loanId);
      } catch (_) {}

      logger.AppLogger.success('Loan deleted successfully');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _handleError('Gagal menghapus data', e, stackTrace);
      // Rollback
      await loadAllData();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Upload image untuk loan item
  Future<String?> uploadImage(String localPath, String itemId) async {
    _setLoading(true);
    try {
      logger.AppLogger.info('Uploading image for item: $itemId');
      final imageUrl = await _persistenceService.uploadImage(localPath, itemId);

      if (imageUrl != null) {
        logger.AppLogger.success('Image uploaded successfully');
        // Invalidate cache so any readers will fetch the new signed URL
        try {
          await _persistenceService.invalidateCache(itemId: itemId);
        } catch (_) {}
      } else {
        logger.AppLogger.warning(
          'Image upload not supported by persistence service',
        );
      }

      return imageUrl;
    } catch (e) {
      logger.AppLogger.error('Failed to upload image: $e', e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Cari loan by ID (dari active atau history)
  LoanItem? findLoanById(String id) {
    try {
      return _activeLoans.firstWhere((item) => item.id == id);
    } catch (_) {
      try {
        return _historyLoans.firstWhere((item) => item.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Filter active loans by search query
  List<LoanItem> searchActiveLoans(String query) {
    if (query.isEmpty) return _activeLoans;

    final lowerQuery = query.toLowerCase();
    return _activeLoans.where((loan) {
      return loan.title.toLowerCase().contains(lowerQuery) ||
          loan.borrower.toLowerCase().contains(lowerQuery) ||
          (loan.contact?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Filter history loans by search query
  List<LoanItem> searchHistoryLoans(String query) {
    if (query.isEmpty) return _historyLoans;

    final lowerQuery = query.toLowerCase();
    return _historyLoans.where((loan) {
      return loan.title.toLowerCase().contains(lowerQuery) ||
          loan.borrower.toLowerCase().contains(lowerQuery) ||
          (loan.contact?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Clear error message
  void clearError() {
    _clearError();
  }

  // Private helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _handleError(String userMessage, Object error, StackTrace stackTrace) {
    _errorMessage = ErrorHandler.getFriendlyMessage(error);
    logger.AppLogger.error('$userMessage: $error', error);
    notifyListeners();
  }
}
