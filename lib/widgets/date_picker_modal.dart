import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';

/// Reusable date picker modal widget with custom Cupertino-style scrolling pickers.
///
/// This widget provides a bottom sheet modal for selecting dates with separate
/// day, month, and year pickers. It includes haptic feedback and smooth animations.
class DatePickerModal {
  DatePickerModal._();

  /// Shows the date picker modal and returns the selected date.
  ///
  /// [context] - BuildContext for showing the modal
  /// [initialDate] - The initially selected date (defaults to today)
  ///
  /// Returns the selected DateTime or null if cancelled.
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
  }) async {
    final now = initialDate ?? DateTime.now();

    // State variables for the modal
    int curDay = now.day;
    int curMonth = now.month;
    int curYear = now.year;

    const startYear = 2020;
    const endYear = 2030;
    const yearCount = endYear - startYear + 1;

    // Controllers for Cupertino pickers
    final dayController = FixedExtentScrollController(initialItem: curDay - 1);
    final monthController = FixedExtentScrollController(
      initialItem: curMonth - 1,
    );
    final yearController = FixedExtentScrollController(
      initialItem: curYear - startYear,
    );

    // Debounce timers for haptic feedback
    Timer? dayDebounce;
    Timer? monthDebounce;
    Timer? yearDebounce;

    void scheduleHaptic(
      Timer? Function() getTimer,
      void Function(Timer?) setTimer,
    ) {
      final t = getTimer();
      t?.cancel();
      final newT = Timer(AppConstants.hapticFeedbackDelay, () {
        HapticFeedback.selectionClick();
      });
      setTimer(newT);
    }

    try {
      final result = await showGeneralDialog<DateTime?>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Pilih Tanggal Pengembalian',
        barrierColor: Colors.black54,
        transitionDuration: AppConstants.dialogTransitionDuration,
        pageBuilder: (ctx, anim1, anim2) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(12),
                    height: 360,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBE1F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 48,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9CCE8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pilih Tanggal Pengembalian',
                              style: GoogleFonts.arimo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0C0315),
                              ).copyWith(decoration: TextDecoration.none),
                            ),
                            Hero(
                              tag: 'date-picker-hero',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8530E4),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Subtitle
                        Text(
                          'Scroll untuk memilih tanggal',
                          style: GoogleFonts.arimo(
                            fontSize: 14,
                            color: const Color(0xFF4A3D5C),
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 12),

                        // Date pickers
                        Expanded(
                          child: Row(
                            children: [
                              // Day picker
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: dayController,
                                  itemExtent: 36,
                                  onSelectedItemChanged: (i) {
                                    setModalState(() => curDay = i + 1);
                                    scheduleHaptic(
                                      () => dayDebounce,
                                      (t) => dayDebounce = t,
                                    );
                                  },
                                  childCount: 31,
                                  itemBuilder: (context, i) {
                                    final isCenter = (i + 1) == curDay;
                                    return Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: GoogleFonts.arimo(
                                          fontSize: isCenter ? 20 : 16,
                                          color: isCenter
                                              ? const Color(0xFF8530E4)
                                              : const Color(0x660C0315),
                                          fontWeight: isCenter
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Month picker
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: monthController,
                                  itemExtent: 36,
                                  onSelectedItemChanged: (i) {
                                    setModalState(() => curMonth = i + 1);
                                    scheduleHaptic(
                                      () => monthDebounce,
                                      (t) => monthDebounce = t,
                                    );
                                  },
                                  childCount: 12,
                                  itemBuilder: (context, i) {
                                    final name = _monthName(i + 1);
                                    final isCenter = (i + 1) == curMonth;
                                    return Center(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.arimo(
                                          fontSize: isCenter ? 18 : 14,
                                          color: isCenter
                                              ? const Color(0xFF8530E4)
                                              : const Color(0x660C0315),
                                          fontWeight: isCenter
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Year picker
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: yearController,
                                  itemExtent: 36,
                                  onSelectedItemChanged: (i) {
                                    setModalState(
                                      () => curYear = startYear + i,
                                    );
                                    scheduleHaptic(
                                      () => yearDebounce,
                                      (t) => yearDebounce = t,
                                    );
                                  },
                                  childCount: yearCount,
                                  itemBuilder: (context, i) {
                                    final y = startYear + i;
                                    final isCenter = y == curYear;
                                    return Center(
                                      child: Text(
                                        '$y',
                                        style: GoogleFonts.arimo(
                                          fontSize: isCenter ? 18 : 14,
                                          color: isCenter
                                              ? const Color(0xFF8530E4)
                                              : const Color(0x660C0315),
                                          fontWeight: isCenter
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Action buttons
                        Row(
                          children: [
                            // Cancel button
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Batal memilih tanggal',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => Navigator.of(ctx).pop(null),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD9CCE8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Batal',
                                          style:
                                              GoogleFonts.arimo(
                                                color: const Color(0xFF0C0315),
                                                fontSize: 16,
                                              ).copyWith(
                                                decoration: TextDecoration.none,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Confirm button
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Konfirmasi tanggal',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      // Clamp day to valid range for selected month/year
                                      final maxD = _daysInMonth(
                                        curYear,
                                        curMonth,
                                      );
                                      final selDay = curDay.clamp(1, maxD);
                                      final picked = DateTime(
                                        curYear,
                                        curMonth,
                                        selDay,
                                      );
                                      HapticFeedback.mediumImpact();
                                      Navigator.of(ctx).pop(picked);
                                    },
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8530E4),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Konfirmasi',
                                          style:
                                              GoogleFonts.arimo(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ).copyWith(
                                                decoration: TextDecoration.none,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      // Clean up timers
      dayDebounce?.cancel();
      monthDebounce?.cancel();
      yearDebounce?.cancel();

      // Dispose controllers
      dayController.dispose();
      monthController.dispose();
      yearController.dispose();

      return result;
    } catch (e) {
      // Clean up on error
      dayDebounce?.cancel();
      monthDebounce?.cancel();
      yearDebounce?.cancel();
      dayController.dispose();
      monthController.dispose();
      yearController.dispose();
      rethrow;
    }
  }

  /// Returns the abbreviated month name in Indonesian
  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[month - 1];
  }

  /// Returns the number of days in a given month/year
  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
