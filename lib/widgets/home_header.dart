import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'offline_banner.dart';
import 'overdue_badge.dart';
import 'search_bar_widget.dart';

class HomeHeader extends StatelessWidget {
  final int visibleCount;
  final int activeCount;
  final int overdueCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Future<void> Function()? onLogout;
  final String? role;
  final VoidCallback? onAdminPressed;
  final VoidCallback? onProfilePressed;

  const HomeHeader({
    super.key,
    required this.visibleCount,
    required this.activeCount,
    required this.overdueCount,
    required this.searchController,
    required this.searchFocusNode,
    this.onLogout,
    this.role,
    this.onAdminPressed,
    this.onProfilePressed,
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
          // reduced vertical padding to make header shorter on small screens
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OfflineBanner(),
              const SizedBox(height: 6.0),
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
                            // smaller title for mobile screens
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '$visibleCount barang sedang dipinjamkan',
                          style: GoogleFonts.arimo(
                            fontSize: 13,
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile avatar
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onProfilePressed,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.12 * 255).round()),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  // Admin button (if admin) + Logout button
                  if (role == 'admin')
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onAdminPressed,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(
                                (0.18 * 255).round(),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                        // slightly smaller touch area so header is more compact
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12.0),

              // Overdue badge
              OverdueBadge(count: overdueCount),

              const SizedBox(height: 12.0),

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
