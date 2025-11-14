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
  final String? role;
  // profile access moved to bottom navigation; header shows role badge (non-clickable)

  const HomeHeader({
    super.key,
    required this.visibleCount,
    required this.activeCount,
    required this.overdueCount,
    required this.searchController,
    required this.searchFocusNode,
    this.role,
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
                  // Role badge for all users (non-clickable). Admin shows icon + label.
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.18 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (role == 'admin') ...[
                            const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                          ] else if ((role ?? 'user') == 'user') ...[
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            (role ?? 'user').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
