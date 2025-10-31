import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A small container with pastel background chosen by index.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    required this.index,
    this.color,
  });

  final Widget child;
  final int index;
  final Color? color;

  Color _pastelForIndex(int i) {
    // Use a reduced/weighted palette for Add/Edit screens so the UI does
    // not overuse the yellow tone (`peachYellow`). We still use three
    // distinct pastel colors, but give the yellow a lower weight so it's
    // displayed less frequently and the UI feels balanced.
    final colors = [
      AppColors.lavender,
      AppColors.mint,
      AppColors.lavender,
      AppColors.peachYellow,
    ];
    return colors[i % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? _pastelForIndex(index);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
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
