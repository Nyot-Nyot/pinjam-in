import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      // Parse JSON in background isolate to avoid jank on main thread
      final parsed = await compute(_parseLoanList, a);
      return parsed.map((e) => LoanItem.fromJson(e)).toList();
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
      // Parse JSON in background isolate to avoid jank on main thread
      final parsed = await compute(_parseLoanList, h);
      return parsed.map((e) => LoanItem.fromJson(e)).toList();
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

  @override
  Future<void> invalidateCache({String? itemId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.activeLoansKey);
      await prefs.remove(StorageKeys.historyLoansKey);
    } catch (_) {}
  }

  @override
  Future<String?> getPublicUrl(String path) async => null;
}

/// Parse a JSON string containing a list of loan maps into a List<Map>.
/// This runs in a background isolate when used with `compute` to keep the
/// main/UI isolate responsive during heavy JSON decoding.
List<Map<String, dynamic>> _parseLoanList(String jsonString) {
  final decoded = jsonDecode(jsonString) as List<dynamic>;
  return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
