import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../models/loan_item.dart';
import '../services/persistence_service.dart';
import '../services/shared_prefs_persistence.dart';
import '../services/supabase_persistence.dart';
import '../theme/app_theme.dart';
import '../utils/date_helper.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';
import '../widgets/loan_card.dart';
import 'add_item_screen.dart';
import 'history_screen.dart';

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

  final List<LoanItem> _active = [];

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
        ErrorHandler.showError(
          context,
          'Gagal menyimpan ke server (autentikasi). Data disimpan secara lokal. Silakan masuk untuk menyinkronkan.',
        );
        return;
      }

      // Surface other persistence errors to the user so failures aren't silent
      ErrorHandler.showError(context, 'Gagal menyimpan data: $e');
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
          status: AppConstants.statusReturned,
          returnedAt: DateHelper.nowUtc(),
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
                      ErrorHandler.showError(
                        context,
                        'Gagal mengunggah gambar (tidak ada URL dikembalikan). User id: ${uid ?? '<anonymous>'}',
                        duration: AppConstants.snackBarDuration,
                      );
                    }
                    return;
                  }
                } catch (e) {
                  if (context.mounted) {
                    ErrorHandler.showError(
                      context,
                      e,
                      customMessage:
                          'Gagal mengunggah gambar. Pastikan Anda sudah login. (user: ${uid ?? '<anon>'})',
                      duration: AppConstants.snackBarLongDuration,
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
                duration: AppConstants.pageTransitionDuration,
                curve: Curves.ease,
              );
            },
            onCancel: () {
              // navigate back to Home page when Add is embedded
              _pageController.animateToPage(
                0,
                duration: AppConstants.quickTransitionDuration,
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
                  duration: AppConstants.snackBarDuration,
                ),
              );

              // Wait for snackbar to be dismissed before permanently deleting from DB
              snackbar.closed.then((reason) async {
                if (reason != SnackBarClosedReason.action) {
                  // User didn't press undo, so delete from database permanently
                  try {
                    await _persistence.deleteItem(item.id);
                  } catch (e) {
                    AppLogger.error(
                      'Error deleting item from database',
                      e,
                      'HomeScreen',
                    );
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
                duration: AppConstants.pageTransitionDuration,
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
      _searchDebounce = Timer(AppConstants.searchDebounceDuration, () {
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
                color: AppTheme.primaryPurple.withOpacity(0.3),
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
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple,
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
                                  ErrorHandler.showError(
                                    context,
                                    'Gagal logout: $e',
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
                          color: AppTheme.primaryPurple,
                          size: 22,
                        ),
                        const SizedBox(width: AppTheme.spacingM),
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

        // List of loan cards or empty state
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Belum Ada Barang',
                  message: _query.isEmpty
                      ? 'Belum ada barang yang dipinjamkan.\nTambahkan barang pertama Anda!'
                      : 'Tidak ada barang yang cocok\ndengan pencarian Anda.',
                  actionLabel: _query.isEmpty ? 'Tambah Barang' : null,
                  onActionPressed: _query.isEmpty
                      ? () {
                          setState(() => _selectedIndex = 1);
                          _pageController.animateToPage(
                            1,
                            duration: AppConstants.pageTransitionDuration,
                            curve: Curves.ease,
                          );
                        }
                      : null,
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return LoanCard(
                        key: ValueKey(item.id),
                        item: item,
                        persistence: _persistence,
                        onComplete: () => _onItemDismissed(item.id),
                        onEdit: (updated) {
                          setState(() {
                            final i = _active.indexWhere(
                              (e) => e.id == updated.id,
                            );
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
                            duration: AppConstants.pageTransitionDuration,
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
          duration: AppConstants.pageTransitionDuration,
          curve: Curves.ease,
        );
      },
    );
  }
}
