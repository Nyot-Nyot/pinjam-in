import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OverdueBadge extends StatelessWidget {
  final int count;

  const OverdueBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count terlambat',
            style: GoogleFonts.arimo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}
