import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/loan_item.dart';
import '../screens/item_detail_screen.dart';
import '../services/persistence_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'storage_image.dart';

/// A card widget displaying an active loan item with swipe-to-complete gesture.
///
/// Features:
/// - Displays item image, title, borrower, and due date
/// - Tap to view item details
/// - Swipe right to mark as completed
/// - Color-coded due date badge
class LoanCard extends StatefulWidget {
  const LoanCard({
    super.key,
    required this.item,
    required this.persistence,
    this.onComplete,
    this.onEdit,
    this.onRequestEdit,
  });

  final LoanItem item;
  final PersistenceService persistence;
  final VoidCallback? onComplete;
  final ValueChanged<LoanItem>? onEdit;
  final ValueChanged<LoanItem>? onRequestEdit;

  @override
  State<LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<LoanCard>
    with SingleTickerProviderStateMixin {
  // horizontal offset of the draggable check button
  double _dragX = 0.0;
  late double _maxDrag;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LoanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the card is reused for a different item, reset drag offset
    if (oldWidget.item.id != widget.item.id) {
      setState(() {
        _dragX = 0.0;
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    // if dragged beyond 70% of available width, consider it complete
    if (_dragX > _maxDrag * 0.7) {
      // animate to end then call onComplete
      _animateTo(_maxDrag).then((_) {
        widget.onComplete?.call();
      });
    } else {
      // animate back to zero
      _animateTo(0.0);
    }
  }

  Future<void> _animateTo(double target) async {
    final start = _dragX;
    final diff = target - start;
    final animation = Tween<double>(begin: 0, end: 1).animate(_anim);
    _anim.reset();
    _anim.addListener(() {
      setState(() {
        _dragX = start + diff * animation.value;
      });
    });
    await _anim.forward();
    _anim.removeListener(() {});
  }

  @override
  Widget build(BuildContext context) {
    // measure max drag based on available width; icon area width 70 + padding
    _maxDrag = MediaQuery.of(context).size.width - 24.0 * 2 - 70 - 24;

    final statusText = widget.item.computedDaysRemaining == null
        ? 'Tanpa batas'
        : (widget.item.computedDaysRemaining! < 0
              ? 'Terlambat ${widget.item.computedDaysRemaining!.abs()} hari'
              : '${widget.item.computedDaysRemaining} hari');
    final badgeColor = widget.item.computedDaysRemaining == null
        ? AppTheme.statusNoLimit
        : (widget.item.computedDaysRemaining! < 0
              ? AppTheme.statusOverdue
              : AppTheme.statusOnTime);
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: AppColors.pastelForId(widget.item.id),
        borderRadius: BorderRadius.circular(18.0),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            offset: Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main info row
            GestureDetector(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(
                      item: widget.item,
                      persistence: widget.persistence,
                    ),
                  ),
                );

                // If the detail screen requested deletion, treat it like a
                // completion / move-to-history action
                if (result is Map<String, dynamic> &&
                    result['action'] == 'delete' &&
                    result['item'] is LoanItem) {
                  widget.onComplete?.call();
                  return;
                }

                if (result is Map<String, dynamic> &&
                    result['action'] == 'edit' &&
                    result['item'] is LoanItem) {
                  widget.onRequestEdit?.call(result['item'] as LoanItem);
                  return;
                }

                if (result is LoanItem) widget.onEdit?.call(result);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image thumbnail
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14.0),
                      child: StorageImage(
                        imagePath: widget.item.imagePath,
                        imageUrl: widget.item.imageUrl,
                        persistence: widget.persistence,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12.0),

                  // Item info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.arimo(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0C0315),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Borrower
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Color(0xFF0C0315),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.item.borrower,
                                style: GoogleFonts.arimo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color.fromRGBO(12, 3, 21, 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Due date badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.arimo(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12.0),

            // Swipe-to-complete area
            SizedBox(
              height: 52,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const knobWidth = 70.0;
                  final fillWidth = (_dragX + knobWidth).clamp(
                    0.0,
                    _maxDrag + knobWidth,
                  );

                  return Stack(
                    children: [
                      // Track with label
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: knobWidth,
                        ),
                        child: Text(
                          'Geser untuk selesaikan',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.arimo(
                            fontSize: 13,
                            color: Color(0xFF4A3D5C),
                          ),
                        ),
                      ),

                      // Progress fill
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: fillWidth,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                        ),
                      ),

                      // Draggable knob
                      Positioned(
                        left: _dragX,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                          child: const SizedBox(
                            width: knobWidth,
                            child: Center(child: _DragKnob()),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The draggable knob with check icon
class _DragKnob extends StatelessWidget {
  const _DragKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.12),
            offset: Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Center(child: Icon(Icons.check, color: Colors.green.shade700)),
    );
  }
}
