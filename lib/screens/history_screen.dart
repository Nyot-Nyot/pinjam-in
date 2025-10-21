import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/loan_item.dart';
import '../services/persistence_service.dart';
import '../widgets/storage_image.dart';
import 'item_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.history,
    required this.persistence,
    this.onDelete,
    this.onRestore,
    this.onRequestEdit,
  });

  final List<LoanItem> history;
  final PersistenceService persistence;
  final ValueChanged<LoanItem>? onDelete;
  final ValueChanged<LoanItem>? onRestore;
  final ValueChanged<LoanItem>? onRequestEdit;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  late final TextEditingController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TextEditingController(text: _query);
    _tc.addListener(() {
      setState(() => _query = _tc.text);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.history
        : widget.history
              .where(
                (e) =>
                    e.title.toLowerCase().contains(_query.toLowerCase()) ||
                    e.borrower.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return SafeArea(
      child: Column(
        children: [
          // Header area
          Container(
            height: 148,
            padding: const EdgeInsets.only(left: 24.0, right: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32.0),
                Text(
                  'Riwayat Pinjaman',
                  style: GoogleFonts.arimo(
                    fontSize: 16,
                    color: const Color(0xFF0C0315),
                  ),
                ),
                const SizedBox(height: 16.0),
                // Search input (match homepage)
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
                      children: [
                        const Icon(Icons.search, color: Color(0xFF8530E4)),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: TextField(
                            controller: _tc,
                            decoration: InputDecoration.collapsed(
                              hintText: 'Cari riwayat...',
                            ),
                            style: GoogleFonts.arimo(
                              fontSize: 15,
                              color: const Color(0xFF4A3D5C),
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

          // List area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat',
                        style: GoogleFonts.arimo(
                          color: const Color(0xFF6B5E78),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _HistoryCard(
                          item: item,
                          persistence: widget.persistence,
                          onDelete: widget.onDelete,
                          onRestore: widget.onRestore,
                          onRequestEdit: widget.onRequestEdit,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
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
          color: LoanItem.pastelForId(item.id),
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
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.arimo(
                        fontSize: 16,
                        color: const Color(0xFF0C0315),
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
