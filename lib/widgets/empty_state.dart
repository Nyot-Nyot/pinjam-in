import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

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
                color: AppTheme.primaryPurpleLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusCircle),
              ),
              child: Icon(
                icon,
                size: AppTheme.iconXl,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),

            // Title
            Text(
              title,
              style: GoogleFonts.arimo(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.arimo(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),

            // Optional action button
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: AppTheme.spacingXxl),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.add, size: AppTheme.iconL),
                label: Text(
                  actionLabel!,
                  style: GoogleFonts.arimo(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXxl,
                    vertical: AppTheme.spacingL,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
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
