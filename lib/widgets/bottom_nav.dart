import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.page,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  // optional continuous page value from PageController.page
  final double? page;

  Alignment _alignForIndex(int i) {
    return i == 0
        ? const Alignment(-1.0, 0)
        : i == 1
        ? const Alignment(0.0, 0)
        : const Alignment(1.0, 0);
  }

  Alignment _alignmentFromPage(double p) {
    // p is expected between 0..(n-1) where n=3 pages. Map to -1..1
    final clamped = p.clamp(0.0, 2.0);
    final t = (clamped / 2.0) * 2.0 - 1.0; // maps 0->-1, 1->0, 2->1
    return Alignment(t, 0);
  }

  @override
  Widget build(BuildContext context) {
    final align = page != null
        ? _alignmentFromPage(page!)
        : _alignForIndex(selectedIndex);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXxl),
        ),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: AppTheme.borderLight, height: 1),
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacingM,
              left: AppTheme.radiusXxl,
              right: AppTheme.radiusXxl,
              bottom: AppTheme.spacingM,
            ),
            child: SizedBox(
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Use Align so the position can be controlled continuously when `page` is provided.
                  Align(
                    alignment: align,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTap(0),
                          borderRadius: BorderRadius.circular(20.0),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: Icon(
                                Icons.home,
                                color: selectedIndex == 0
                                    ? Colors.white
                                    : const Color(0xFF0C0315),
                                size: 26.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTap(1),
                          borderRadius: BorderRadius.circular(20.0),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: Icon(
                                Icons.add,
                                color: selectedIndex == 1
                                    ? Colors.white
                                    : const Color(0xFF0C0315),
                                size: 24.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTap(2),
                          borderRadius: BorderRadius.circular(20.0),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: Icon(
                                Icons.history,
                                color: selectedIndex == 2
                                    ? Colors.white
                                    : const Color(0xFF0C0315),
                                size: 24.0,
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
        ],
      ),
    );
  }
}
