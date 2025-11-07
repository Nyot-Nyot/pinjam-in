import 'package:flutter/material.dart';
import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/loan_item.dart';
import '../providers/loan_provider.dart';
import '../providers/persistence_provider.dart';
import '../services/persistence_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/storage_image.dart';
import 'item_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.onDelete,
    this.onRestore,
    this.onRequestEdit,
  });
  final ValueChanged<LoanItem>? onDelete;
  final ValueChanged<LoanItem>? onRestore;
  final ValueChanged<LoanItem>? onRequestEdit;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin<HistoryScreen> {
  String _query = '';
  late final TextEditingController _tc;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tc = TextEditingController(text: _query);
    _tc.addListener(() {
      // Debounce user typing to avoid frequent rebuilds on large lists
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _query = _tc.text);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tc.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loanProvider = Provider.of<LoanProvider?>(context);
    final persistence = Provider.of<PersistenceProvider>(context).service!;
    final history = loanProvider?.historyLoans ?? <LoanItem>[];

    final filtered = _query.isEmpty
        ? history
        : history
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
                color: AppTheme.primaryPurple.withAlpha((0.3 * 255).round()),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Riwayat Pinjaman',
                    style: GoogleFonts.arimo(
                        fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${filtered.length} barang telah dikembalikan',
                    style: GoogleFonts.arimo(
                        fontSize: 13,
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                    const SizedBox(height: 12.0),

                    // Search input with white background (smaller for mobile)
                    Container(
                      height: 44.0,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.1 * 255).round()),
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
                            size: 18,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: TextField(
                              controller: _tc,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Cari riwayat...',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              style: GoogleFonts.arimo(
                                fontSize: 14,
                                color: const Color(0xFF4A3D5C),
                              ),
                            ),
                          ),
                          if (_tc.text.isNotEmpty)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              icon: const Icon(
                                Icons.clear,
                                size: 18,
                                color: Color(0xFF6B5E78),
                              ),
                              onPressed: () {
                                _tc.clear();
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16.0),

        // List area or empty state
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.history_outlined,
                  title: 'Belum Ada Riwayat',
                  message: _query.isEmpty
                      ? 'Riwayat barang yang sudah dikembalikan\nakan muncul di sini.'
                      : 'Tidak ada riwayat yang cocok\ndengan pencarian Anda.',
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _HistoryCard(
                        key: ValueKey(item.id),
                        item: item,
                        persistence: persistence,
                        onDelete: widget.onDelete,
                        onRestore: widget.onRestore,
                        onRequestEdit: widget.onRequestEdit,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
    required this.item,
    required this.persistence,
    this.onDelete,
    this.onRestore,
    this.onRequestEdit,
  });

  final LoanItem item;
  final PersistenceService persistence;
  final ValueChanged<LoanItem>? onDelete;
  final ValueChanged<LoanItem>? onRestore;
  final ValueChanged<LoanItem>? onRequestEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              item: item,
              persistence: persistence,
              isInHistory: true,
            ),
          ),
        );
        if (result is Map<String, dynamic>) {
          if (result['action'] == 'delete' && result['item'] is LoanItem) {
            onDelete?.call(result['item'] as LoanItem);
          } else if (result['action'] == 'restore' &&
              result['item'] is LoanItem) {
            onRestore?.call(result['item'] as LoanItem);
          } else if (result['action'] == 'edit' && result['item'] is LoanItem) {
            onRequestEdit?.call(result['item'] as LoanItem);
          }
        }
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        decoration: BoxDecoration(
          color: AppColors.pastelForId(item.id),
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: StorageImage(
                    imagePath: item.imagePath,
                    imageUrl: item.imageUrl,
                    persistence: persistence,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Main info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.arimo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0C0315),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 14,
                          color: Color(0xFF4A3D5C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.borrower,
                            style: GoogleFonts.arimo(
                              fontSize: 14,
                              color: const Color(0xFF4A3D5C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // status pill (check) moved to a subtle corner badge
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 36,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF45B56E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '✓',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
