import 'package:flutter/material.dart';

class LoanItem {
  LoanItem({
    required this.id,
    required this.title,
    required this.borrower,
    required this.daysRemaining,
    this.note,
    required this.color,
  });

  final String id;
  final String title;
  final String borrower;
  final int daysRemaining;
  final String? note;
  final Color color;
}
