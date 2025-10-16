import 'package:flutter/material.dart';

import '../models/loan_item.dart';
import 'add_item_screen.dart';

/// Thin compatibility wrapper kept to preserve imports elsewhere.
class EditItemScreen extends StatelessWidget {
  const EditItemScreen({super.key, required this.item});

  final LoanItem item;

  @override
  Widget build(BuildContext context) =>
      AddItemScreen(initial: item, showBackButton: true);
}
