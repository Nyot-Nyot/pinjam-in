// The file performs mounted checks and captures messenger/navigator where
// appropriate. Suppress the analyzer rule for using BuildContext across
// async gaps when the usage is intentionally guarded.
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/loan_item.dart';
import '../services/persistence_service.dart';
import '../services/share_service.dart';
import '../utils/error_handler.dart';
import '../widgets/storage_image.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.persistence,
    this.isInHistory = false,
  });

  final LoanItem item;
  final PersistenceService persistence;
  final bool isInHistory;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    return '${local.day} ${_monthName(local.month)} ${local.year}';
  }

  String _monthName(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return names[(m - 1).clamp(0, 11)];
  }

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
                child: StorageImage(
                  imagePath: widget.item.imagePath,
                  imageUrl: widget.item.imageUrl,
                  persistence: widget.persistence,
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
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
                        if (!widget.isInHistory) {
                          Navigator.of(context).pop<Map<String, dynamic>>({
                            'action': 'edit',
                            'item': widget.item,
                          });
                          return;
                        }

                        if (!mounted) return;
                        final choice = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit'),
                                  onTap: () => Navigator.of(ctx).pop('edit'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.restore),
                                  title: const Text('Kembalikan ke Aktif'),
                                  onTap: () => Navigator.of(ctx).pop('restore'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete_forever),
                                  title: const Text('Hapus Permanen'),
                                  onTap: () => Navigator.of(ctx).pop('delete'),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.close),
                                  title: const Text('Batal'),
                                  onTap: () => Navigator.of(ctx).pop(null),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (choice == 'edit') {
                          if (!mounted) return;
                          Navigator.of(context).pop<Map<String, dynamic>>({
                            'action': 'edit',
                            'item': widget.item,
                          });
                        } else if (choice == 'restore') {
                          if (!mounted) return;
                          Navigator.of(context).pop<Map<String, dynamic>>({
                            'action': 'restore',
                            'item': widget.item,
                          });
                        } else if (choice == 'delete') {
                          // Ask for confirmation; capture result then check mounted
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus permanen'),
                              content: const Text(
                                'Item ini akan dihapus permanen. Lanjutkan?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text(
                                    'Hapus',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (!mounted) return;
                          if (confirm == true) {
                            Navigator.of(context).pop<Map<String, dynamic>>({
                              'action': 'delete',
                              'item': widget.item,
                            });
                          }
                        }
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
                            color: widget.item.computedDaysRemaining == null
                                ? const Color(0xFFF6EFFD)
                                : (widget.item.computedDaysRemaining! < 0
                                      ? const Color(0x30DC2626)
                                      : const Color(0x1A8530E4)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.item.computedDaysRemaining == null
                                ? 'Tanpa batas'
                                : (widget.item.computedDaysRemaining! < 0
                                      ? 'Terlambat ${widget.item.computedDaysRemaining!.abs()}h'
                                      : '${widget.item.computedDaysRemaining} hari'),
                            style: GoogleFonts.arimo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.item.computedDaysRemaining == null
                                  ? const Color(0xFF8530E4)
                                  : (widget.item.computedDaysRemaining! < 0
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF8530E4)),
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
                          onPressed: () async {
                            final contact = widget.item.contact ?? '';
                            if (contact.isEmpty) {
                              if (!mounted) return;
                              ErrorHandler.showInfo(
                                context,
                                'Kontak belum disetel',
                              );
                              return;
                            }

                            // Capture ScaffoldMessenger early to avoid using State.context after awaits
                            final messenger = ScaffoldMessenger.of(context);

                            // Try launching tel: URI; if not supported, copy contact to clipboard
                            final uri = Uri(scheme: 'tel', path: contact);
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                await Clipboard.setData(
                                  ClipboardData(text: contact),
                                );
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Nomor disalin ke clipboard'),
                                  ),
                                );
                              }
                            } catch (e) {
                              await Clipboard.setData(
                                ClipboardData(text: contact),
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Nomor disalin ke clipboard'),
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
                      _formatDate(widget.item.createdAt),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Target Kembali',
                      widget.item.dueDate != null
                          ? _formatDate(widget.item.dueDate)
                          : 'Tanpa batas',
                      Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 8),
                    // Show 'Selesai' for items coming from History; otherwise keep current active label.
                    _statusRow(
                      'Status',
                      widget.isInHistory ? 'Selesai' : 'Aktif',
                      bgColor: widget.isInHistory
                          ? const Color(0x1A16A34A)
                          : null,
                      textColor: widget.isInHistory
                          ? const Color(0xFF16A34A)
                          : null,
                    ),

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

  Future<void> _onShare() async {
    final text = StringBuffer()
      ..writeln(widget.item.title)
      ..writeln('Peminjam: ${widget.item.borrower}')
      ..writeln(
        'Dibuat: ${widget.item.createdAt?.toLocal().toIso8601String() ?? 'Tidak diketahui'}',
      )
      ..writeln(
        'Target kembali: ${widget.item.dueDate?.toLocal().toIso8601String() ?? 'Tidak ditentukan'}',
      )
      ..writeln(
        'Sisa hari: ${widget.item.computedDaysRemaining ?? 'Tanpa batas'}',
      )
      ..writeln('Sisa hari: ${widget.item.daysRemaining ?? 'Tanpa batas'}')
      ..writeln(widget.item.note ?? '');

    final success = await ShareService.share(
      text.toString(),
      subject: 'Detail pinjaman: ${widget.item.title}',
    );
    // Notify user what happened. In the current desktop-first setup the
    // implementation copies the summary to clipboard, so inform user about
    // that. If in future a native share is used, you may want to change the
    // message accordingly.
    if (success) {
      if (!mounted) return;
      ErrorHandler.showInfo(context, 'Rangkuman disalin ke clipboard');
    } else {
      if (!mounted) return;
      ErrorHandler.showError(
        context,
        'Gagal membagikan; ringkasan disalin ke clipboard',
      );
    }
  }

  Future<void> _onDeletePressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pinjaman'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus catatan pinjaman ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      // Pop with a special payload so the caller can perform deletion/move-to-history.
      Navigator.of(
        context,
      ).pop<Map<String, dynamic>>({'action': 'delete', 'item': widget.item});
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

  Widget _statusRow(
    String label,
    String value, {
    Color? bgColor,
    Color? textColor,
  }) {
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
                  color: bgColor ?? const Color(0x1A8530E4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: GoogleFonts.arimo(
                    color: textColor ?? const Color(0xFF8530E4),
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
