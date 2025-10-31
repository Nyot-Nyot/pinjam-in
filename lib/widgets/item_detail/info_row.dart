import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small info row used in item detail (icon + label + value)
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFFD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF6B5E78)),
        ),
        const SizedBox(width: 12),
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
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.arimo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C0315),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
