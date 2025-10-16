import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/loan_item.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.item});

  final LoanItem item;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD),
      body: Stack(
        children: [
          // Decorative top area (image / color anchor)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 320,
                width: double.infinity,
                color: const Color(0xFFD9CCE8),
                child: const Center(
                  child: Text('📦', style: TextStyle(fontSize: 120)),
                ),
              ),
            ),
          ),

          // Header row (outside the drawer) with large hit targets
          Positioned(
            left: 0,
            right: 0,
            top: 24,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _largeIconButton(
                      icon: Icons.arrow_back,
                      background: const Color(0xFFF1E9FB),
                      onTap: () => Navigator.of(context).pop(),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Detail Barang',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.arimo(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C0315),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    _largeIconButton(
                      icon: Icons.edit,
                      background: const Color(0xFF8530E4),
                      iconColor: Colors.white,
                      onTap: () async {
                        // Request edit by popping back to the caller with a payload
                        Navigator.of(context).pop<Map<String, dynamic>>({
                          'action': 'edit',
                          'item': widget.item,
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Drawer content
          Positioned(
            left: 0,
            right: 0,
            top: 280,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEBE1F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.12),
                    offset: Offset(0, 12),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9CCE8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Title + status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.title,
                                style: GoogleFonts.arimo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0C0315),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Informasi barang & pinjaman',
                                style: GoogleFonts.arimo(
                                  fontSize: 13,
                                  color: const Color(0xFF6B5E78),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.item.daysRemaining < 0
                                ? const Color(0x30DC2626)
                                : const Color(0x1A8530E4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.item.daysRemaining < 0
                                ? 'Terlambat ${widget.item.daysRemaining.abs()}h'
                                : '${widget.item.daysRemaining} hari',
                            style: GoogleFonts.arimo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.item.daysRemaining < 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF8530E4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Borrower row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Text(
                            (widget.item.borrower
                                    .split(' ')
                                    .map((s) => s.isNotEmpty ? s[0] : '')
                                    .take(2)
                                    .join())
                                .toUpperCase(),
                            style: GoogleFonts.arimo(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.borrower,
                                style: GoogleFonts.arimo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Peminjam',
                                style: GoogleFonts.arimo(
                                  fontSize: 13,
                                  color: const Color(0xFF6B5E78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // If contact is present, ideally call via intent — placeholder for now
                            if (widget.item.contact != null &&
                                widget.item.contact!.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Hubungi ${widget.item.contact}',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Kontak belum disetel'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.call,
                            color: Color(0xFF6B5E78),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFD4C3E6)),
                    const SizedBox(height: 12),

                    // Info tiles
                    _infoRow(
                      'Tanggal Pinjam',
                      '1 Okt 2025',
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Target Kembali',
                      '5 Okt 2025',
                      Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 8),
                    _statusRow('Status', 'Aktif'),

                    // Note
                    if (widget.item.note != null &&
                        widget.item.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Catatan',
                        style: GoogleFonts.arimo(
                          color: const Color(0xFF6B5E78),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.04),
                              offset: const Offset(0, 6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.item.note!,
                          style: GoogleFonts.arimo(
                            color: const Color(0xFF0C0315),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF6EFFD),
                                  side: const BorderSide(
                                    color: Color(0xFFD4C3E6),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _onShare,
                                icon: const Icon(
                                  Icons.share,
                                  color: Color(0xFF0C0315),
                                ),
                                label: Text(
                                  'Bagikan',
                                  style: GoogleFonts.arimo(
                                    color: const Color(0xFF0C0315),
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _onDeletePressed,
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: Text(
                              'Hapus',
                              style: GoogleFonts.arimo(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onShare() {
    final text = StringBuffer()
      ..writeln(widget.item.title)
      ..writeln('Peminjam: ${widget.item.borrower}')
      ..writeln('Sisa hari: ${widget.item.daysRemaining}')
      ..writeln(widget.item.note ?? '');

    Share.share(text.toString(), subject: 'Detail pinjaman: ${widget.item.title}');
  }

  Future<void> _onDeletePressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pinjaman'),
        content: const Text('Apakah Anda yakin ingin menghapus catatan pinjaman ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      // Pop with a special payload so the caller can perform deletion/move-to-history.
      Navigator.of(context).pop<Map<String, dynamic>>({'action': 'delete', 'item': widget.item});
    }
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFFD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF6B5E78)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.arimo(
                  color: const Color(0xFF6B5E78),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.arimo(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C0315),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.arimo(
                  color: const Color(0xFF6B5E78),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1A8530E4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.arimo(
                    color: const Color(0xFF8530E4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _largeIconButton({
    required IconData icon,
    required Color background,
    Color iconColor = Colors.black,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.12),
                  offset: Offset(0, 8),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}
