import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/loan_item.dart';
import 'persistence_service.dart';

class FirestorePersistence implements PersistenceService {
  FirestorePersistence({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String _collection = 'loan_items';

  Map<String, dynamic> _toDoc(LoanItem item, {required bool isHistory}) => {
        'id': item.id,
        'title': item.title,
        'borrower': item.borrower,
        'daysRemaining': item.daysRemaining,
        'note': item.note,
        'contact': item.contact,
        'imagePath': item.imagePath,
  'color': item.color.toARGB32(),
        'isHistory': isHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  LoanItem _fromDoc(Map<String, dynamic> d) => LoanItem(
        id: d['id'] as String,
        title: d['title'] as String,
        borrower: d['borrower'] as String,
        daysRemaining: d['daysRemaining'] == null ? null : (d['daysRemaining'] as num).toInt(),
        note: d['note'] as String?,
        contact: d['contact'] as String?,
        imagePath: d['imagePath'] as String?,
        color: d['color'] == null ? LoanItem.pastelForId(d['id'] as String) : Color((d['color'] as int)),
      );

  @override
  Future<List<LoanItem>> loadActive() async {
    final snap = await _db.collection(_collection).where('isHistory', isEqualTo: false).orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => _fromDoc(d.data())).toList();
  }

  @override
  Future<List<LoanItem>> loadHistory() async {
    final snap = await _db.collection(_collection).where('isHistory', isEqualTo: true).orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => _fromDoc(d.data())).toList();
  }

  Future<void> _writeBatch(List<LoanItem> items, {required bool isHistory}) async {
    final batch = _db.batch();
    for (final item in items) {
      final ref = _db.collection(_collection).doc(item.id);
      batch.set(ref, _toDoc(item, isHistory: isHistory));
    }
    await batch.commit();
  }

  @override
  Future<void> saveActive(List<LoanItem> active) async {
    // For simplicity, we write/overwrite documents for provided items and mark them as not history.
    await _writeBatch(active, isHistory: false);
  }

  @override
  Future<void> saveHistory(List<LoanItem> history) async {
    await _writeBatch(history, isHistory: true);
  }

  @override
  Future<void> saveAll({required List<LoanItem> active, required List<LoanItem> history}) async {
    // Use a batched approach: overwrite all provided docs. Note: doesn't delete removed docs.
    final batch = _db.batch();
    for (final item in active) {
      final ref = _db.collection(_collection).doc(item.id);
      batch.set(ref, _toDoc(item, isHistory: false));
    }
    for (final item in history) {
      final ref = _db.collection(_collection).doc(item.id);
      batch.set(ref, _toDoc(item, isHistory: true));
    }
    await batch.commit();
  }
}
