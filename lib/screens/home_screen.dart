import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../models/loan_item.dart';
import '../providers/auth_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/persistence_provider.dart';
import '../utils/date_helper.dart';
import '../utils/error_handler.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/empty_state.dart';
import '../widgets/home_header.dart';
import '../widgets/loan_card.dart';
import 'add_item_screen.dart';
import 'admin_dashboard.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;
  late final ValueNotifier<double> _pageNotifier;
  DateTime _lastPageValueUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  LoanItem? _editingItem;
  String _query = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  Timer? _searchDebounce;

  // Lists are now provided by LoanProvider

  // persistence keys moved to SharedPrefsPersistence implementation

  // Loading/saving handled by LoanProvider (via PersistenceProvider)

  void _onItemDismissed(String id) {
    final loanProvider = Provider.of<LoanProvider?>(context, listen: false);
    if (loanProvider == null) return;
    // Delegate to provider to mark as returned
    loanProvider.markAsReturned(id, DateHelper.nowUtc());
  }

  Future<void> _handleLogout() async {
    try {
      // AuthProvider handles sign out; fallback to direct supabase sign out
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Gagal logout: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loanProvider = Provider.of<LoanProvider>(context);
    final persistenceProvider = Provider.of<PersistenceProvider>(context);

    // If provider not yet initialized show loader
    if (persistenceProvider.service == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Use PageView so Home <-> Add <-> History feel like adjacent pages
    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD),
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _selectedIndex = idx),
        children: [
          _buildHome(loanProvider, persistenceProvider.service!),
          // embed Add screen so bottom nav stays visible; use onSave to receive items
          AddItemScreen(
            initial: _editingItem,
            onSave: (newItem) async {
              final loanProvider = Provider.of<LoanProvider?>(
                context,
                listen: false,
              );
              if (loanProvider == null) return;

              String? imageUrl = newItem.imageUrl;
              if (newItem.imagePath != null) {
                try {
                  final res = await loanProvider.uploadImage(
                    newItem.imagePath!,
                    newItem.id,
                  );
                  if (res != null) {
                    imageUrl = res;
                  } else {
                    if (context.mounted) {
                      ErrorHandler.showError(
                        context,
                        'Gagal mengunggah gambar (tidak ada URL dikembalikan).',
                      );
                    }
                    return;
                  }
                } catch (e) {
                  if (context.mounted) {
                    ErrorHandler.showError(context, e);
                  }
                  return;
                }
              }

              final itemToSave = newItem.copyWith(imageUrl: imageUrl);
              if (_editingItem != null) {
                await loanProvider.updateLoan(itemToSave);
              } else {
                await loanProvider.addLoan(itemToSave);
              }

              setState(() => _editingItem = null);
              _pageController.animateToPage(
                0,
                duration: AppConstants.pageTransitionDuration,
                curve: Curves.ease,
              );
            },
            onCancel: () {
              _pageController.animateToPage(
                0,
                duration: AppConstants.quickTransitionDuration,
                curve: Curves.ease,
              );
            },
          ),
          HistoryScreen(
            onDelete: (item) async {
              final loanProvider = Provider.of<LoanProvider?>(
                context,
                listen: false,
              );
              if (loanProvider == null) return;
              await loanProvider.deleteLoan(item.id);
            },
            onRestore: (item) async {
              final loanProvider = Provider.of<LoanProvider?>(
                context,
                listen: false,
              );
              if (loanProvider == null) return;
              await loanProvider.restoreLoan(item.id);
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
          // Profile screen (moved from header to bottom nav)
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  @override
  void initState() {
    super.initState();
    // Data loading is handled by providers; LoanProvider created by ProxyProvider will load data
    _pageNotifier = ValueNotifier<double>(_selectedIndex.toDouble());
    _pageController = PageController(initialPage: _selectedIndex)
      ..addListener(() {
        final p = _pageController.hasClients && _pageController.page != null
            ? _pageController.page!
            : _selectedIndex.toDouble();
        // Throttle updates to avoid flooding the notifier during fast scrolls.
        final now = DateTime.now();
        if (now.difference(_lastPageValueUpdate) >
            const Duration(milliseconds: 50)) {
          _lastPageValueUpdate = now;
          _pageNotifier.value = p;
        }
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
    _pageNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Widget _buildHome(LoanProvider loanProvider, dynamic persistence) {
    final authProvider = Provider.of<AuthProvider?>(context);
    final visible = _query.isEmpty
        ? loanProvider.activeLoans
        : loanProvider.searchActiveLoans(_query);
    final overdueCount = loanProvider.activeLoans
        .where(
          (e) =>
              e.computedDaysRemaining != null && e.computedDaysRemaining! < 0,
        )
        .length;

    return Column(
      children: [
        // Header (extracted)
        HomeHeader(
          visibleCount: visible.length,
          activeCount: loanProvider.activeLoans.length,
          overdueCount: overdueCount,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          onLogout: _handleLogout,
          role: authProvider?.role,
          onAdminPressed: () {
            // Navigate to admin dashboard
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AdminDashboard()));
          },
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
                    separatorBuilder: (_, _) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return LoanCard(
                        key: ValueKey(item.id),
                        item: item,
                        persistence: persistence,
                        onComplete: () => _onItemDismissed(item.id),
                        onEdit: (updated) {
                          // update via provider
                          loanProvider.updateLoan(updated);
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
      controller: _pageController,
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
