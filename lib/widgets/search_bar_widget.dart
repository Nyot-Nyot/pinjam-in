import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.search, color: AppTheme.primaryPurple, size: 18),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Semantics(
              textField: true,
              label: 'Pencarian barang atau nama peminjam',
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hintText ?? 'Cari barang atau nama peminjam',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Color(0xFF6B5E78),
                          ),
                          onPressed: () {
                            controller.clear();
                            focusNode.requestFocus();
                          },
                        ),
                ),
                style: GoogleFonts.arimo(
                  fontSize: 14,
                  color: const Color(0xFF4A3D5C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
