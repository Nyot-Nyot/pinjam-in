import 'package:intl/intl.dart';

/// Helper class for date formatting and calculations.
/// Centralizes all date-related operations used throughout the app.
class DateHelper {
  DateHelper._(); // Private constructor to prevent instantiation

  // ==================== Date Formatters ====================

  /// Format date as "dd MMM yyyy" (e.g., "14 Jan 2025").
  static final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  /// Format date as "dd/MM/yyyy" (e.g., "14/01/2025").
  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yyyy');

  /// Format date as "EEEE, dd MMMM yyyy" (e.g., "Senin, 14 Januari 2025").
  static final DateFormat _fullDateFormat = DateFormat('EEEE, dd MMMM yyyy');

  /// Format datetime as "dd MMM yyyy HH:mm" (e.g., "14 Jan 2025 14:30").
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

  // ==================== Public Formatting Methods ====================

  /// Format a date for display in cards and details.
  /// Returns formatted string like "14 Jan 2025".
  static String formatDate(DateTime date) {
    return _displayDateFormat.format(date);
  }

  /// Format a date in short form.
  /// Returns formatted string like "14/01/2025".
  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Format a date in full form with day name.
  /// Returns formatted string like "Senin, 14 Januari 2025".
  static String formatFullDate(DateTime date) {
    return _fullDateFormat.format(date);
  }

  /// Format a datetime with time.
  /// Returns formatted string like "14 Jan 2025 14:30".
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  // ==================== Date Calculations ====================

  /// Calculate days remaining from now until the due date.
  ///
  /// Normalizes both dates to start of day (00:00:00) for accurate day counting.
  /// Returns:
  /// - Positive number if due date is in the future
  /// - Zero if due date is today
  /// - Negative number if due date is in the past (overdue)
  ///
  /// Example:
  /// ```dart
  /// final dueDate = DateTime(2025, 2, 1);
  /// final days = DateHelper.daysUntil(dueDate); // e.g., 18 days
  /// ```
  static int daysUntil(DateTime dueDate) {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final dueDateNormalized = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    );
    return dueDateNormalized.difference(nowDate).inDays;
  }

  /// Calculate days remaining from a specific date until the due date.
  ///
  /// Normalizes both dates to start of day (00:00:00) for accurate day counting.
  /// Useful for calculating days from borrow date or other reference dates.
  static int daysBetween(DateTime fromDate, DateTime toDate) {
    final fromNormalized = DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    );
    final toNormalized = DateTime(toDate.year, toDate.month, toDate.day);
    return toNormalized.difference(fromNormalized).inDays;
  }

  /// Check if a due date is overdue (past today).
  ///
  /// Returns true if the due date is before today (at start of day).
  static bool isOverdue(DateTime dueDate) {
    return daysUntil(dueDate) < 0;
  }

  /// Check if a due date is today.
  static bool isDueToday(DateTime dueDate) {
    return daysUntil(dueDate) == 0;
  }

  /// Check if a due date is within the next N days.
  ///
  /// Example:
  /// ```dart
  /// if (DateHelper.isWithinDays(item.dueDate, 3)) {
  ///   // Show warning: due soon!
  /// }
  /// ```
  static bool isWithinDays(DateTime dueDate, int days) {
    final remaining = daysUntil(dueDate);
    return remaining >= 0 && remaining <= days;
  }

  // ==================== Date Generation ====================

  /// Get current date/time as DateTime.now().
  ///
  /// This method exists primarily for consistency and easier mocking in tests.
  static DateTime now() => DateTime.now();

  /// Get current UTC date/time.
  static DateTime nowUtc() => DateTime.now().toUtc();

  /// Add days to current date.
  ///
  /// Example:
  /// ```dart
  /// final dueDate = DateHelper.addDaysToNow(7); // One week from now
  /// ```
  static DateTime addDaysToNow(int days) {
    return DateTime.now().add(Duration(days: days));
  }

  /// Add days to a specific date.
  static DateTime addDays(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  // ==================== Normalization ====================

  /// Normalize a DateTime to start of day (00:00:00.000).
  ///
  /// Useful for date-only comparisons without time components.
  ///
  /// Example:
  /// ```dart
  /// final today = DateHelper.startOfDay(DateTime.now());
  /// final dueDay = DateHelper.startOfDay(dueDate);
  /// final days = dueDay.difference(today).inDays;
  /// ```
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Normalize a DateTime to end of day (23:59:59.999).
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  // ==================== Timestamp Generation ====================

  /// Generate a timestamp string for file naming.
  ///
  /// Returns milliseconds since epoch as string.
  /// Useful for generating unique filenames.
  ///
  /// Example:
  /// ```dart
  /// final filename = '${DateHelper.timestamp()}.jpg';
  /// // Output: "1705234567890.jpg"
  /// ```
  static String timestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ==================== Date Presets ====================

  /// Get a date N days from now for quick date selection.
  ///
  /// Common presets:
  /// - 3 days
  /// - 7 days (1 week)
  /// - 14 days (2 weeks)
  /// - 30 days (1 month)
  static DateTime presetDate(int days) {
    return addDaysToNow(days);
  }
}
