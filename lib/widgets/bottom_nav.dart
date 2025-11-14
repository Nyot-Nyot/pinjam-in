import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom navigation with a moving circular highlight. The highlight is driven
/// by an optional [PageController]. When provided, the widget listens to the
/// controller and updates the highlight position every frame via
/// [AnimatedBuilder] (smooth). When absent, it falls back to using
/// [selectedIndex] as a static position.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.controller,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final PageController? controller;

  @override
  Widget build(BuildContext context) {
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
              child: LayoutBuilder(
                builder: (ctx, cc) {
                  final maxW = cc.maxWidth;
                  // width/height of the circular highlight
                  const double box = 64.0;

                  double leftForPage(double p) {
                    // support 4 pages (0..3)
                    final step = (maxW - box) / 3.0;
                    return (p.clamp(0.0, 3.0)) * step;
                  }

                  Widget buildStack(double effectivePage) {
                    final left = leftForPage(effectivePage);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Highlight (placed below the icons so icons remain on top).
                        // Use a transform for movement so the translation can be
                        // handled by the compositor instead of forcing repaints.
                        Positioned(
                          left: 0,
                          top: (72 - box) / 2.0,
                          child: Transform.translate(
                            offset: Offset(left, 0),
                            child: RepaintBoundary(
                              child: Container(
                                width: box,
                                height: box,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusXxl,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _navItem(Icons.home, 0, selectedIndex == 0),
                            _navItem(Icons.add, 1, selectedIndex == 1),
                            _navItem(Icons.history, 2, selectedIndex == 2),
                            _navItem(Icons.person, 3, selectedIndex == 3),
                          ],
                        ),
                      ],
                    );
                  }

                  if (controller != null) {
                    return AnimatedBuilder(
                      animation: controller!,
                      builder: (context, _) {
                        final p =
                            (controller!.hasClients && controller!.page != null)
                            ? controller!.page!
                            : selectedIndex.toDouble();
                        return buildStack(p);
                      },
                    );
                  }

                  // Fallback: static position
                  return buildStack(selectedIndex.toDouble());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int idx, bool active) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(idx),
        borderRadius: BorderRadius.circular(20.0),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Icon(
              icon,
              color: active ? Colors.white : const Color(0xFF0C0315),
              size: icon == Icons.home ? 26.4 : 24.0,
            ),
          ),
        ),
      ),
    );
  }
}
