import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../models/loan_item.dart';
import 'persistence_service.dart';

class SharedPrefsPersistence implements PersistenceService {
  @override
  Future<List<LoanItem>> loadActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = prefs.getString(StorageKeys.activeLoansKey);
      if (a == null) return [];
      final list = jsonDecode(a) as List<dynamic>;
      return list
          .map((e) => LoanItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<LoanItem>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final h = prefs.getString(StorageKeys.historyLoansKey);
      if (h == null) return [];
      final list = jsonDecode(h) as List<dynamic>;
      return list
          .map((e) => LoanItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveActive(List<LoanItem> active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.activeLoansKey,
        jsonEncode(active.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Future<void> saveHistory(List<LoanItem> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.historyLoansKey,
        jsonEncode(history.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  Future<void> saveAll({
    required List<LoanItem> active,
    required List<LoanItem> history,
  }) async {
    await Future.wait([saveActive(active), saveHistory(history)]);
  }

  @override
  Future<String?> uploadImage(String localPath, String itemId) async {
    // Shared preferences backend doesn't support remote uploads. Return null
    // so callers can fall back to the local path.
    return null;
  }

  @override
  Future<String?> currentUserId() async {
    // No auth for local persistence
    return null;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    // For SharedPreferences, deletion is handled by saveAll() which stores
    // the entire list. No separate delete operation needed.
  }
}
