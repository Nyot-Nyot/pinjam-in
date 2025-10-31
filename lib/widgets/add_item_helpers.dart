import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A small container with pastel background chosen by index.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, required this.index});

  final Widget child;
  final int index;

  Color _pastelForIndex(int i) {
    final colors = AppColors.pastelPalette;
    return colors[i % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pastelForIndex(index),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// A small chip used for preset date buttons.
class PresetChip extends StatelessWidget {
  const PresetChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6D9F6)),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.arimo(
            color: const Color(0xFF4A3D5C),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A white rounded action button used next to the date picker.
class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6D9F6)),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.arimo(
            color: const Color(0xFF0C0315),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
