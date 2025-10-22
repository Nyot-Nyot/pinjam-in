import 'dart:math';

import 'package:flutter/material.dart';

/// Application color palette.
/// Contains all colors used throughout the app for consistent theming.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ==================== Pastel Colors ====================

  /// Pastel palette for loan item cards and UI elements.
  /// These colors provide a soft, pleasant visual experience.
  static const List<Color> pastelPalette = [
    warmPink, // 0xFFFF95B8
    peachYellow, // 0xFFFFCE6B
    lavender, // 0xFFB78CFF
    mint, // 0xFF79F0B0
  ];

  // Individual pastel colors (can be used directly)
  static const Color warmPink = Color(0xFFFF95B8);
  static const Color peachYellow = Color(0xFFFFCE6B);
  static const Color lavender = Color(0xFFB78CFF);
  static const Color mint = Color(0xFF79F0B0);

  // ==================== Pastel Color Helpers ====================

  /// Returns a random pastel color from the shared palette.
  ///
  /// Optionally provide a [Random] instance for deterministic behavior in tests.
  ///
  /// Example:
  /// ```dart
  /// final color = AppColors.randomPastel();
  /// ```
  static Color randomPastel([Random? rng]) {
    final r = rng ?? Random();
    return pastelPalette[r.nextInt(pastelPalette.length)];
  }

  /// Deterministically map a string ID to a pastel color from the palette.
  ///
  /// Uses DJB2-style hash over the id's UTF-16 code units so the same id
  /// always maps to the same palette index across app restarts.
  /// This ensures consistent colors for each loan item.
  ///
  /// Example:
  /// ```dart
  /// final itemColor = AppColors.pastelForId(item.id);
  /// ```
  static Color pastelForId(String id) {
    if (id.isEmpty) return pastelPalette[0];

    var hash = 5381;
    for (final unit in id.codeUnits) {
      hash = ((hash << 5) + hash) + unit; // hash * 33 + unit
    }

    final idx = hash.abs() % pastelPalette.length;
    return pastelPalette[idx];
  }

  // ==================== Semantic Colors ====================

  // Status colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color error = Color(0xFFF44336); // Red
  static const Color info = Color(0xFF2196F3); // Blue

  // Overdue indicator
  static const Color overdueRed = Color(
    0xFFFF5252,
  ); // Bright red for overdue items

  // ==================== Background Colors ====================

  static const Color scaffoldBackground = Color(0xFFF8F9FD);
  static const Color cardBackground = Colors.white;

  // ==================== Text Colors ====================

  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textHint = Color(0xFFBDC3C7);

  // ==================== Border Colors ====================

  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFFBDBDBD);
}
