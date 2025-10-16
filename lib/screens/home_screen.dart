import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/loan_item.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/local_image.dart';
import 'add_item_screen.dart';
import 'history_screen.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  double _pageValue = 0.0;
  LoanItem? _editingItem;
  String _query = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounce;

  final List<LoanItem> _active = [
    LoanItem(
      id: '1',
      title: 'Power Bank Xiaomi 10000mAh',
      borrower: 'Andi Wijaya',
      daysRemaining: -9,
      note: 'Kapasitas sudah berkurang, harap kembalikan sebelum 10 Okt',
      color: LoanItem.pastelForId('1'),
    ),
    LoanItem(
      id: '2',
      title: 'Buku: Clean Code',
      borrower: 'Siti Rahmawati',
      daysRemaining: -4,
      color: LoanItem.pastelForId('2'),
    ),
    LoanItem(
      id: '3',
      title: 'Kabel HDMI 2 Meter',
      borrower: 'Budi Santoso',
      daysRemaining: -12,
      color: LoanItem.pastelForId('3'),
    ),
  ];

  final List<LoanItem> _history = [];

  static const String _kActiveKey = 'loan_active_v1';
  static const String _kHistoryKey = 'loan_history_v1';

  Future<void> _saveAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kActiveKey,
        jsonEncode(_active.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _kHistoryKey,
        jsonEncode(_history.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = prefs.getString(_kActiveKey);
      final h = prefs.getString(_kHistoryKey);
      if (a != null) {
        final list = jsonDecode(a) as List<dynamic>;
        _active
          ..clear()
          ..addAll(
            list.map((e) => LoanItem.fromJson(e as Map<String, dynamic>)),
          );
      }
      if (h != null) {
        final list = jsonDecode(h) as List<dynamic>;
        _history
          ..clear()
          ..addAll(
            list.map((e) => LoanItem.fromJson(e as Map<String, dynamic>)),
          );
      }
    } catch (_) {}
  }

  void _onItemDismissed(String id) {
    setState(() {
      final idx = _active.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final item = _active.removeAt(idx);
        _history.add(item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} dipindahkan ke Riwayat'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                setState(() {
                  // restore to the top of active list
                  _history.removeWhere((h) => h.id == item.id);
                  _active.insert(0, item);
                });
                _saveAll();
              },
            ),
          ),
        );
        _saveAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use PageView so Home <-> Add <-> History feel like adjacent pages
    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD),
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _selectedIndex = idx),
        children: [
          _buildHome(),
          // embed Add screen so bottom nav stays visible; use onSave to receive items
          AddItemScreen(
            initial: _editingItem,
            onSave: (newItem) {
              setState(() {
                if (_editingItem != null) {
                  final i = _active.indexWhere((e) => e.id == newItem.id);
                  if (i != -1) _active[i] = newItem;
                } else {
                  _active.insert(0, newItem);
                }
                _editingItem = null;
              });
              _saveAll();
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.ease,
              );
            },
            onCancel: () {
              // navigate back to Home page when Add is embedded
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
          ),
          HistoryScreen(history: _history),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
    _pageController = PageController(initialPage: _selectedIndex)
      ..addListener(() {
        final p = _pageController.hasClients && _pageController.page != null
            ? _pageController.page!
            : _selectedIndex.toDouble();
        setState(() {
          _pageValue = p;
        });
      });
    _searchController = TextEditingController(text: '');
    _searchFocusNode = FocusNode();
    _searchController.addListener(() {
      // update UI (clear button) immediately, but debounce the actual filtering
      setState(() {});
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _query = _searchController.text);
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Widget _buildHome() {
    final visible = _query.isEmpty
        ? _active
        : _active
              .where(
                (e) =>
                    e.title.toLowerCase().contains(_query.toLowerCase()) ||
                    e.borrower.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();
    return SafeArea(
      child: Column(
        children: [
          // Header area (220 tall in design)
          Container(
            height: 220,
            padding: const EdgeInsets.only(left: 24.0, right: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32.0),
                Text(
                  'Pinjaman Aktif',
                  style: GoogleFonts.arimo(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C0315),
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${visible.length} barang sedang dipinjamkan',
                  style: GoogleFonts.arimo(
                    fontSize: 14,
                    color: const Color(0xFF4A3D5C),
                  ),
                ),
                // Red pill
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: const Color(0x1AF62026), // rgba(220,38,38,0.1)
                    borderRadius: BorderRadius.circular(999),
                  ),
                  width: 110,
                  height: 28,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_active.where((e) => e.daysRemaining != null && e.daysRemaining! < 0).length} terlambat',
                          style: GoogleFonts.arimo(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16.0),

                // Search input — increased height to match design and more vertical padding
                Container(
                  margin: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    height: 56.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBE1F7),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search,
                          color: Color(0xFF8530E4),
                          size: 20,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Semantics(
                            textField: true,
                            label: 'Pencarian barang atau nama peminjam',
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Cari barang atau nama peminjam',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        icon: const Icon(
                                          Icons.clear,
                                          size: 20,
                                          color: Color(0xFF6B5E78),
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchFocusNode.requestFocus();
                                        },
                                      ),
                              ),
                              style: GoogleFonts.arimo(
                                fontSize: 15,
                                color: const Color(0xFF4A3D5C),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // small gap between header/search and the list
          const SizedBox(height: 12.0),

          // List of loan cards
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  return _LoanCard(
                    key: ValueKey(item.id),
                    item: item,
                    onComplete: () => _onItemDismissed(item.id),
                    onEdit: (updated) {
                      setState(() {
                        final i = _active.indexWhere((e) => e.id == updated.id);
                        if (i != -1) _active[i] = updated;
                      });
                      _saveAll();
                    },
                    onRequestEdit: (itemToEdit) {
                      // prepare edit and navigate to Add page
                      setState(() {
                        _editingItem = itemToEdit;
                      });
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.ease,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add page is embedded in the PageView; no placeholder function needed.

  Widget _buildBottomNav() {
    return BottomNav(
      selectedIndex: _selectedIndex,
      page: _pageValue,
      onTap: (i) {
        setState(() => _selectedIndex = i);
        if (i == 1) {
          // open add page and reset editing state
          setState(() => _editingItem = null);
        }
        _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 350),
          curve: Curves.ease,
        );
      },
    );
  }
}

class _LoanCard extends StatefulWidget {
  const _LoanCard({
    super.key,
    required this.item,
    this.onComplete,
    this.onEdit,
    this.onRequestEdit,
  });

  final LoanItem item;
  final VoidCallback? onComplete;
  final ValueChanged<LoanItem>? onEdit;
  final ValueChanged<LoanItem>? onRequestEdit;

  @override
  State<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<_LoanCard>
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
  void didUpdateWidget(covariant _LoanCard oldWidget) {
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

    // Improved, more readable card layout while preserving draggable completion
    final statusText = widget.item.daysRemaining == null
        ? 'Tanpa batas'
        : (widget.item.daysRemaining! < 0
              ? 'Terlambat ${widget.item.daysRemaining!.abs()} hari'
              : '${widget.item.daysRemaining} hari');
    final badgeColor = widget.item.daysRemaining == null
        ? const Color(0xFF6B5E78)
        : (widget.item.daysRemaining! < 0
              ? Colors.red.shade600
              : const Color(0xFF8530E4));

    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: widget.item.color,
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
            // Main info row (with Edit button)
            Stack(
              children: [
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(item: widget.item),
                      ),
                    );

                    // If the detail screen requested deletion, treat it like a
                    // completion / move-to-history action by invoking the
                    // onComplete callback supplied by the parent.
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
                    children: [
                      // Left visual: show image if available, otherwise placeholder
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14.0),
                          child: widget.item.imagePath != null
                              ? LocalImage(
                                  path: widget.item.imagePath,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(14.0),
                                )
                              : const Center(
                                  child: Text(
                                    '📦',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(width: 12.0),

                      // Title and borrower (with due-time badge below borrower)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.arimo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0C0315),
                              ),
                            ),
                            const SizedBox(height: 6),
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
                            // due-time tag placed under borrower
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
                // removed inline edit button: editing is done from the detail screen
              ],
            ),

            const SizedBox(height: 12.0),

            // Swipe area with progress fill matching drag position
            SizedBox(
              height: 52,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final knobWidth = 70.0;
                  final fillWidth = (_dragX + knobWidth).clamp(
                    0.0,
                    _maxDrag + knobWidth,
                  );

                  return Stack(
                    children: [
                      // Track (label centered and padded so it's not covered by the knob)
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(horizontal: knobWidth),
                        child: Text(
                          'Geser untuk selesaikan',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.arimo(
                            fontSize: 13,
                            color: const Color(0xFF4A3D5C),
                          ),
                        ),
                      ),

                      // Fill that grows as user drags
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
                          child: SizedBox(
                            width: knobWidth,
                            child: Center(
                              child: Container(
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
                                child: Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ),
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
