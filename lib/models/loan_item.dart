import 'dart:math';

import 'package:flutter/material.dart';

class LoanItem {
  LoanItem({
    required this.id,
    required this.title,
    required this.borrower,
    this.daysRemaining,
    this.createdAt,
    this.dueDate,
    this.returnedAt,
    this.note,
    this.contact,
    this.imagePath,
    this.imageUrl,
    this.ownerId,
    this.status = 'active',
  });

  final String id;
  final String title;
  final String borrower;

  /// legacy: stored snapshot of days remaining at save time. Prefer using
  /// [dueDate] for up-to-date calculations.
  final int? daysRemaining;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final DateTime? returnedAt;
  final String? note;
  final String? contact;

  /// Local cached image path (device-local). For remote sync prefer `imageUrl`.
  final String? imagePath;
  final String? imageUrl;
  final String? ownerId;

  /// 'active' | 'returned' | 'deleted'
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'borrower': borrower,
    'daysRemaining': daysRemaining,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'returnedAt': returnedAt?.millisecondsSinceEpoch,
    'note': note,
    'contact': contact,
    'imagePath': imagePath,
    'imageUrl': imageUrl,
    'ownerId': ownerId,
    'status': status,
  };

  static LoanItem fromJson(Map<String, dynamic> j) {
    // Backwards compatible: older stored objects may only have daysRemaining.
    DateTime? parseMs(Object? o) {
      if (o == null) return null;
      if (o is int) return DateTime.fromMillisecondsSinceEpoch(o);
      if (o is String) {
        final v = int.tryParse(o);
        if (v != null) return DateTime.fromMillisecondsSinceEpoch(v);
        try {
          return DateTime.parse(o);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final due = parseMs(j['dueDate']);
    final created = parseMs(j['createdAt']);
    final returned = parseMs(j['returnedAt']);

    final int? legacyDays = j['daysRemaining'] == null
        ? null
        : (j['daysRemaining'] as num).toInt();

    return LoanItem(
      id: j['id'] as String,
      title: j['title'] as String,
      borrower: j['borrower'] as String,
      daysRemaining: legacyDays,
      createdAt: created,
      dueDate: due,
      returnedAt: returned,
      note: j['note'] as String?,
      contact: j['contact'] as String?,
      imagePath: j['imagePath'] as String?,
      imageUrl: j['imageUrl'] as String?,
      ownerId: j['ownerId'] as String?,
      status: j['status'] as String? ?? 'active',
    );
  }

  // A small pastel palette used across the app.
  static const List<Color> pastelPalette = [
    Color(0xFFFF95B8), // warm pink
    Color(0xFFFFCE6B), // peach/yellow
    Color(0xFFB78CFF), // lavender
    Color(0xFF79F0B0), // mint
  ];

  /// Returns a random pastel color from the shared palette.
  static Color randomPastel([Random? rng]) {
    final r = rng ?? Random();
    return pastelPalette[r.nextInt(pastelPalette.length)];
  }

  /// Deterministically map an item id to a pastel color from the shared palette.
  ///
  /// We use a simple DJB2-style hash over the id's UTF-16 code units so the
  /// same id always maps to the same palette index across app restarts.
  static Color pastelForId(String id) {
    if (id.isEmpty) return pastelPalette[0];
    var hash = 5381;
    for (final unit in id.codeUnits) {
      hash = ((hash << 5) + hash) + unit; // hash * 33 + unit
    }
    final idx = hash.abs() % pastelPalette.length;
    return pastelPalette[idx];
  }

  /// Compute up-to-date days remaining using [dueDate] when available.
  /// Falls back to the legacy [daysRemaining] snapshot if [dueDate] is not set.
  int? get computedDaysRemaining {
    if (returnedAt != null) return null;
    if (dueDate != null) {
      final now = DateTime.now().toUtc();
      return dueDate!.toUtc().difference(now).inDays;
    }
    return daysRemaining;
  }

  LoanItem copyWith({
    String? id,
    String? title,
    String? borrower,
    int? daysRemaining,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? returnedAt,
    String? note,
    String? contact,
    String? imagePath,
    String? imageUrl,
    String? ownerId,
    String? status,
  }) {
    return LoanItem(
      id: id ?? this.id,
      title: title ?? this.title,
      borrower: borrower ?? this.borrower,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      returnedAt: returnedAt ?? this.returnedAt,
      note: note ?? this.note,
      contact: contact ?? this.contact,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
    );
  }
}
