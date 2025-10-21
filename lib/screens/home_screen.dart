import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_item.dart';
import '../services/persistence_service.dart';
import '../services/shared_prefs_persistence.dart';
import '../services/supabase_persistence.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/storage_image.dart';
import 'add_item_screen.dart';
import 'history_screen.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Optional persistence service for easier testing and swapping implementations.
  const HomeScreen({super.key, this.persistence});

  final PersistenceService? persistence;

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
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      dueDate: DateTime.now().toUtc().add(const Duration(days: -9)),
    ),
    LoanItem(
      id: '2',
      title: 'Buku: Clean Code',
      borrower: 'Siti Rahmawati',
      daysRemaining: -4,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 10)),
      dueDate: DateTime.now().toUtc().add(const Duration(days: -4)),
    ),
    LoanItem(
      id: '3',
      title: 'Kabel HDMI 2 Meter',
      borrower: 'Budi Santoso',
      daysRemaining: -12,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
      dueDate: DateTime.now().toUtc().add(const Duration(days: -12)),
    ),
  ];

  final List<LoanItem> _history = [];

  // persistence keys moved to SharedPrefsPersistence implementation

  PersistenceService get _persistence {
    // If a persistence impl was passed explicitly, use it.
    if (widget.persistence != null) return widget.persistence!;

    // Prefer Supabase persistence if the Supabase client is initialized.
    try {
      final client = Supabase.instance.client;
      return SupabasePersistence.fromClient(client);
    } catch (_) {}

    // Fallback to shared prefs local persistence.
    return SharedPrefsPersistence();
  }

  Future<void> _saveAll() async {
    try {
      await _persistence.saveAll(active: _active, history: _history);
    } catch (e) {
      // If the SupabasePersistence signaled unauthenticated / RLS 403
      // fall back to local shared prefs and notify the user.
      final msg = e.toString();
      if (msg.contains('Tidak terautentikasi') || msg.contains('RLS')) {
        // Fallback: save locally
        final local = SharedPrefsPersistence();
        try {
          await local.saveAll(active: _active, history: _history);
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan ke server (autentikasi). Data disimpan secara lokal. Silakan masuk untuk menyinkronkan.',
            ),
          ),
        );
        return;
      }

      // Surface other persistence errors to the user so failures aren't silent
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data: $e')),
      );
      // Re-throw so callers can also handle if needed
      rethrow;
    }
  }

  Future<void> _loadAll() async {
    try {
      final a = await _persistence.loadActive();
      final h = await _persistence.loadHistory();
      _active
        ..clear()
        ..addAll(a);
      _history
        ..clear()
        ..addAll(h);
    } catch (_) {}
  }

  void _onItemDismissed(String id) {
    setState(() {
      final idx = _active.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final item = _active.removeAt(idx);
        // mark as returned so the persistence backend stores correct status
        final returned = item.copyWith(
          status: 'returned',
          returnedAt: DateTime.now().toUtc(),
        );
        _history.add(returned);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} dipindahkan ke Riwayat'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                setState(() {
                  // restore to the top of active list and clear returned metadata
                  _history.removeWhere((h) => h.id == item.id);
                  _active.insert(
                    0,
                    item.copyWith(status: 'active', returnedAt: null),
                  );
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

            onSave: (newItem) async {
              // Ensure we know the current user id for owner assignment and
              // for diagnosing upload permission problems.
              String? uid;
              try {
                uid = await _persistence.currentUserId();
              } catch (_) {
                uid = null;
              }

              // If the item has a local image path, attempt upload and show
              // any errors to the user so they're not silent.
              String? imageUrl = newItem.imageUrl;
              if (newItem.imagePath != null) {
                try {
                  final res = await _persistence.uploadImage(
                    newItem.imagePath!,
                    newItem.id,
                  );
                  if (res != null) {
                    imageUrl = res;
                  } else {
                    // Upload returned null (no URL) — treat as failure and
                    // abort saving to avoid RLS/upsert errors.
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Gagal mengunggah gambar (tidak ada URL dikembalikan). Silakan coba lagi. User id: ${uid ?? '<anonymous>'}',
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                    return;
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Gagal mengunggah gambar: $e. Pastikan Anda sudah login dan bucket storage membolehkan upload. (user: ${uid ?? '<anon>'})',
                        ),
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                  // Abort saving since upload failed
                  return;
                }
              }

              // Build the item and assign ownerId immediately so saveAll
              // includes it in the upsert payload.
              final itemToSave = LoanItem(
                id: newItem.id,
                title: newItem.title,
                borrower: newItem.borrower,
                daysRemaining: newItem.daysRemaining,
                createdAt: newItem.createdAt,
                dueDate: newItem.dueDate,
                returnedAt: newItem.returnedAt,
                note: newItem.note,
                contact: newItem.contact,
                imagePath: newItem.imagePath,
                imageUrl: imageUrl,
                ownerId: newItem.ownerId ?? uid,
                status: newItem.status,
              );

              setState(() {
                if (_editingItem != null) {
                  final i = _active.indexWhere((e) => e.id == itemToSave.id);
                  if (i != -1) _active[i] = itemToSave;
                } else {
                  _active.insert(0, itemToSave);
                }
                _editingItem = null;
              });
              // Ensure ownerId is set to current user if backend supports auth
              try {
                final uid = await _persistence.currentUserId();
                if (uid != null) {
                  setState(() {
                    final idx = _active.indexWhere(
                      (e) => e.id == itemToSave.id,
                    );
                    if (idx != -1) {
                      _active[idx] = _active[idx].copyWith(ownerId: uid);
                    }
                  });
                }
              } catch (_) {}
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
          HistoryScreen(
            history: _history,
            persistence: _persistence,
            onDelete: (item) async {
              // Find index so we can restore to same position on undo
              final idx = _history.indexWhere((h) => h.id == item.id);
              if (idx == -1) return;

              setState(() {
                _history.removeAt(idx);
              });
              _saveAll();

              final messenger = ScaffoldMessenger.of(context);
              final snackbar = messenger.showSnackBar(
                SnackBar(
                  content: Text('"${item.title}" dihapus permanen'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      setState(() {
                        _history.insert(idx, item);
                      });
                      _saveAll();
                    },
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );

              // Wait for snackbar to be dismissed before permanently deleting from DB
              snackbar.closed.then((reason) async {
                if (reason != SnackBarClosedReason.action) {
                  // User didn't press undo, so delete from database permanently
                  try {
                    await _persistence.deleteItem(item.id);
                  } catch (e) {
                    print('Error deleting item from database: $e');
                  }
                }
              });
            },
            onRestore: (item) {
              setState(() {
                _history.removeWhere((h) => h.id == item.id);
                // Clear returned metadata when restoring
                final restored = item.copyWith(
                  status: 'active',
                  returnedAt: null,
                );
                _active.insert(0, restored);
              });
              try {
                _saveAll();
              } catch (_) {}
            },
            onRequestEdit: (item) {
              setState(() => _editingItem = item);
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 350),
                curve: Curves.ease,
              );
            },
          ),
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
    return Column(
      children: [
        // Header area with gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8530E4),
                const Color(0xFF9D5FE8),
                const Color(0xFFB48FEC),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8530E4).withOpacity(0.3),
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
                              '${visible.length} barang sedang dipinjamkan',
                              style: GoogleFonts.arimo(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
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
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      'Batal',
                                      style: GoogleFonts.arimo(
                                        color: const Color(0xFF6B5E78),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8530E4),
                                    ),
                                    child: Text(
                                      'Logout',
                                      style: GoogleFonts.arimo(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (shouldLogout == true && mounted) {
                              try {
                                // Logout from Supabase
                                if (_persistence is SupabasePersistence) {
                                  await Supabase.instance.client.auth.signOut();
                                }

                                if (mounted) {
                                  // Navigate to login screen
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/login');
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal logout: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
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

                  // Red pill for overdue items
                  const SizedBox(height: 16.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_active.where((e) => e.computedDaysRemaining != null && e.computedDaysRemaining! < 0).length} terlambat',
                          style: GoogleFonts.arimo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20.0),

                  // Search input with white background
                  Container(
                    height: 56.0,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search,
                          color: Color(0xFF8530E4),
                          size: 22,
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
                ],
              ),
            ),
          ),
        ),
        // small gap between header/search and the list
        const SizedBox(height: 16.0),

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
                  persistence: _persistence,
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
    final statusText = widget.item.computedDaysRemaining == null
        ? 'Tanpa batas'
        : (widget.item.computedDaysRemaining! < 0
              ? 'Terlambat ${widget.item.computedDaysRemaining!.abs()} hari'
              : '${widget.item.computedDaysRemaining} hari');
    final badgeColor = widget.item.computedDaysRemaining == null
        ? const Color(0xFF6B5E78)
        : (widget.item.computedDaysRemaining! < 0
              ? Colors.red.shade600
              : const Color(0xFF8530E4));

    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: LoanItem.pastelForId(widget.item.id),
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
                        builder: (_) => ItemDetailScreen(
                          item: widget.item,
                          persistence: widget.persistence,
                        ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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

                      // Title and borrower (with due-time badge below borrower)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
