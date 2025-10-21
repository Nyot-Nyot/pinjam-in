import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable empty state widget displaying an icon, title, message, and optional action button.
///
/// Used to show when there's no data to display (e.g., no items, no history).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  /// The icon to display in the circular background
  final IconData icon;

  /// The main title text
  final String title;

  /// The description message (can include \n for line breaks)
  final String message;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action button callback
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in circular background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEBE1F7),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                icon,
                size: 64,
                color: const Color(0xFF8530E4),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: GoogleFonts.arimo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.arimo(
                fontSize: 15,
                color: const Color(0xFF6B5E78),
                height: 1.5,
              ),
            ),

            // Optional action button
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  actionLabel!,
                  style: GoogleFonts.arimo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8530E4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
