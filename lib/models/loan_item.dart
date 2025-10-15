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
}
