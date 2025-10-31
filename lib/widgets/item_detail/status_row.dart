import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? bgColor;
  final Color? textColor;

  const StatusRow({
    super.key,
    required this.label,
    required this.value,
    this.bgColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.arimo(
                  color: const Color(0xFF6B5E78),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bgColor ?? const Color(0x1A8530E4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.arimo(
                    color: textColor ?? const Color(0xFF8530E4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
