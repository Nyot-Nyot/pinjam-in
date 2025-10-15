import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/loan_item.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({Key? key, required this.item, this.onSave})
    : super(key: key);

  final LoanItem item;
  final ValueChanged<LoanItem>? onSave;

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _titleController;
  late TextEditingController _borrowerController;
  late TextEditingController _noteController;
  late TextEditingController _contactController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _borrowerController = TextEditingController(text: widget.item.borrower);
    _noteController = TextEditingController(text: widget.item.note ?? '');
    _contactController = TextEditingController(text: widget.item.contact ?? '');
    // derive a date from daysRemaining
    _selectedDate = DateTime.now().add(
      Duration(days: widget.item.daysRemaining),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _borrowerController.dispose();
    _noteController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _applyPreset(int days) {
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _onSave() {
    final title = _titleController.text.trim();
    final borrower = _borrowerController.text.trim();
    if (title.isEmpty || borrower.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama barang dan peminjam wajib diisi')),
      );
      return;
    }

    final daysRemaining = _selectedDate == null
        ? widget.item.daysRemaining
        : _selectedDate!.difference(DateTime.now()).inDays;

    final updated = LoanItem(
      id: widget.item.id,
      title: title,
      borrower: borrower,
      daysRemaining: daysRemaining,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      contact: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      color: widget.item.color,
    );

    widget.onSave?.call(updated);
    Navigator.of(context).pop<LoanItem>(updated);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = _selectedDate == null
        ? 'Pilih tanggal'
        : '${_selectedDate!.day} ${_monthName(_selectedDate!.month)} ${_selectedDate!.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Edit Barang',
          style: GoogleFonts.arimo(color: const Color(0xFF0C0315)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0C0315)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Foto Barang',
              style: GoogleFonts.arimo(
                fontSize: 14,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // placeholder for photo picker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Picker foto belum diimplementasikan'),
                  ),
                );
              },
              child: Container(
                height: 128,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(217, 204, 232, 0.3),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: const Color(0xFFD4C3E6),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Tambah Foto',
                    style: GoogleFonts.arimo(color: const Color(0xFF4A3D5C)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Nama Barang',
              style: GoogleFonts.arimo(
                fontSize: 14,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Color.fromRGBO(217, 204, 232, 0.3),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                controller: _titleController,
                style: GoogleFonts.arimo(fontSize: 16),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Nama Peminjam',
              style: GoogleFonts.arimo(
                fontSize: 14,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Color.fromRGBO(217, 204, 232, 0.3),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                controller: _borrowerController,
                style: GoogleFonts.arimo(fontSize: 16),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Kontak (opsional)',
              style: GoogleFonts.arimo(
                fontSize: 14,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Color.fromRGBO(217, 204, 232, 0.3),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contactController,
                      style: GoogleFonts.arimo(fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Nomor telepon atau nama kontak',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      try {
                        final permitted =
                            await FlutterContacts.requestPermission();
                        if (!mounted) return;
                        if (!permitted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Izin kontak ditolak'),
                            ),
                          );
                          return;
                        }

                        // load minimal contact info (name + phones)
                        final contacts = await FlutterContacts.getContacts(
                          withProperties: true,
                        );
                        if (!mounted) return;
                        if (contacts.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak ada kontak di perangkat'),
                            ),
                          );
                          return;
                        }

                        // show a simple selection dialog
                        final choice = await showDialog<Contact?>(
                          context: context,
                          builder: (ctx) => SimpleDialog(
                            title: const Text('Pilih Kontak'),
                            children: contacts.take(20).map((c) {
                              final subtitle = c.phones.isNotEmpty
                                  ? c.phones.first.number
                                  : '';
                              return SimpleDialogOption(
                                onPressed: () => Navigator.of(ctx).pop(c),
                                child: ListTile(
                                  title: Text(c.displayName),
                                  subtitle: Text(subtitle),
                                ),
                              );
                            }).toList(),
                          ),
                        );

                        if (!mounted) return;
                        if (choice != null) {
                          final name = choice.displayName;
                          final phone = choice.phones.isNotEmpty
                              ? choice.phones.first.number
                              : '';
                          final display = name.isNotEmpty
                              ? '$name • $phone'
                              : phone;
                          setState(() {
                            _contactController.text = display;
                          });
                        }
                      } catch (e) {
                        if (e is MissingPluginException) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Picker kontak tidak tersedia pada build saat ini. Coba hentikan aplikasi lalu jalankan ulang (flutter run) pada perangkat Android/iOS. Jika Anda menjalankan di web/desktop, fitur ini tidak didukung.',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal memilih kontak: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.contact_phone,
                      color: Color(0xFF6B5E78),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Tanggal Target Kembali',
              style: GoogleFonts.arimo(
                fontSize: 14,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color.fromRGBO(133, 48, 228, 0.08),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dikembalikan pada',
                            style: GoogleFonts.arimo(
                              fontSize: 12,
                              color: const Color(0xFF4A3D5C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedDateLabel,
                            style: GoogleFonts.arimo(
                              fontSize: 16,
                              color: const Color(0xFF8530E4),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _pickCustomDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _presetChip('3 Hari', () => _applyPreset(3)),
                      _presetChip('1 Minggu', () => _applyPreset(7)),
                      _presetChip('2 Minggu', () => _applyPreset(14)),
                      _presetChip('1 Bulan', () => _applyPreset(30)),
                      _actionButton('Pilih Tanggal Custom', _pickCustomDate),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Catatan',
              style: GoogleFonts.arimo(
                fontSize: 14,
                color: const Color(0xFF0C0315),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD9CCE8).withOpacity(0.3),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                controller: _noteController,
                style: GoogleFonts.arimo(fontSize: 16),
                maxLines: 4,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Tambahkan catatan penting...',
                ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6EFFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.arimo(color: const Color(0xFF0C0315)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8530E4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _onSave,
                    child: Text(
                      'Simpan',
                      style: GoogleFonts.arimo(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF8530E4).withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.arimo(color: const Color(0xFF8530E4)),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD9CCE8).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.arimo(color: const Color(0xFF0C0315)),
      ),
    ),
  );

  String _monthName(int m) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return names[(m - 1).clamp(0, 11)];
  }
}
