import 'package:flutter/material.dart';

/// App-wide theme colors and design tokens.
///
/// Centralizes all color values and spacing constants used throughout the app.
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // Primary Colors
  static const Color primaryPurple = Color(0xFF8530E4);
  static const Color primaryPurpleLight = Color(0xFFEBE1F7);
  static const Color primaryPurpleLighter = Color(0xFFF6EFFD);

  // Text Colors
  static const Color textPrimary = Color(0xFF0C0315);
  static const Color textSecondary = Color(0xFF6B5E78);
  static const Color textMuted = Color(0xFF4A3D5C);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF6EFFD);
  static const Color backgroundCard = Color(0xFFEBE1F7);
  static const Color backgroundWhite = Colors.white;

  // Border Colors
  static const Color borderLight = Color(0xFFE6DBF8);
  static const Color borderMedium = Color(0xFFD9CCE8);

  // Status Colors
  static const Color statusOverdue = Color(0xFFE53935); // red.shade600
  static const Color statusOnTime = primaryPurple;
  static const Color statusNoLimit = Color(0xFF6B5E78);
  static const Color statusComplete = Color(0xFF43A047); // green.shade600

  // Spacing Constants
  static const double spacingXs = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // Border Radius Constants
  static const double radiusS = 10.0;
  static const double radiusM = 14.0;
  static const double radiusL = 16.0;
  static const double radiusXl = 18.0;
  static const double radiusXxl = 20.0;
  static const double radiusCircle = 60.0;

  // Icon Sizes
  static const double iconS = 14.0;
  static const double iconM = 18.0;
  static const double iconL = 20.0;
  static const double iconXl = 64.0;

  // Shadow
  static const List<BoxShadow> shadowLight = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.08),
      offset: Offset(0, 6),
      blurRadius: 12,
    ),
  ];

  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.12),
      offset: Offset(0, 6),
      blurRadius: 12,
    ),
  ];
}
