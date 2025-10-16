import 'dart:math';

import 'package:flutter/material.dart';

class LoanItem {
  LoanItem({
    required this.id,
    required this.title,
    required this.borrower,
    required this.daysRemaining,
    this.note,
    this.contact,
    required this.color,
  });

  final String id;
  final String title;
  final String borrower;
  final int daysRemaining;
  final String? note;
  final String? contact;
  final Color color;

  // A small pastel palette used across the app.
  static const List<Color> pastelPalette = [
    Color(0xFFFF95B8), // warm pink
    Color(0xFF7FD8FF), // ice blue
    Color(0xFFFFCE6B), // peach/yellow
    Color(0xFFB78CFF), // lavender
    Color(0xFF79F0B0), // mint
    Color(0xFFF4D9C4), // warm beige
    Color(0xFFB88EF5), // soft purple
  ];

  /// Returns a random pastel color from the shared palette.
  static Color randomPastel([Random? rng]) {
    final r = rng ?? Random();
    return pastelPalette[r.nextInt(pastelPalette.length)];
  }
}
