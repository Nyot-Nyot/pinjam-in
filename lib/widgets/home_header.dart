import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'overdue_badge.dart';
import 'search_bar_widget.dart';
import 'offline_banner.dart';

class HomeHeader extends StatelessWidget {
  final int visibleCount;
  final int activeCount;
  final int overdueCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Future<void> Function()? onLogout;

  const HomeHeader({
    super.key,
    required this.visibleCount,
    required this.activeCount,
    required this.overdueCount,
    required this.searchController,
    required this.searchFocusNode,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryPurple,
            Color(0xFF9D5FE8),
            Color(0xFFB48FEC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withAlpha((0.3 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OfflineBanner(),
              const SizedBox(height: 8.0),
              // Title with logout button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pinjaman Aktif',
                          style: GoogleFonts.arimo(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '$visibleCount barang sedang dipinjamkan',
                          style: GoogleFonts.arimo(
                            fontSize: 14,
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Logout button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Logout',
                              style: GoogleFonts.arimo(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              'Apakah Anda yakin ingin keluar?',
                              style: GoogleFonts.arimo(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  'Batal',
                                  style: GoogleFonts.arimo(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                ),
                                child: Text(
                                  'Logout',
                                  style: GoogleFonts.arimo(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (shouldLogout == true && onLogout != null) {
                          await onLogout!();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // Overdue badge
              OverdueBadge(count: overdueCount),

              const SizedBox(height: 20.0),

              // Search bar
              SearchBarWidget(
                controller: searchController,
                focusNode: searchFocusNode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
