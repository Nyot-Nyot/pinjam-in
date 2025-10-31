import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small reusable form field widgets used by AddItemScreen.
///
/// These accept controllers and callbacks so the parent retains ownership of
/// the text controllers and validation state.

class TitleField extends StatelessWidget {
  const TitleField({super.key, required this.controller, required this.error});

  final TextEditingController controller;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nama Barang *',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.arimo(fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Contoh: Power Bank Hitam',
            ),
          ),
        ),
        if (error)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Nama barang wajib diisi',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
      ],
    );
  }
}

class BorrowerContactFields extends StatelessWidget {
  const BorrowerContactFields({
    super.key,
    required this.borrowerController,
    required this.contactController,
    required this.borrowerError,
    required this.onPickContact,
  });

  final TextEditingController borrowerController;
  final TextEditingController contactController;
  final bool borrowerError;
  final VoidCallback onPickContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Peminjam',
          style: GoogleFonts.arimo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0C0315),
          ),
        ),
        const SizedBox(height: 12),

        // Nama Peminjam
        Text(
          'Nama Peminjam *',
          style: GoogleFonts.arimo(
            fontSize: 13,
            color: const Color(0xFF0C0315),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: TextField(
            controller: borrowerController,
            style: GoogleFonts.arimo(fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Contoh: Budi Santoso',
            ),
          ),
        ),
        if (borrowerError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Nama peminjam wajib diisi',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),

        const SizedBox(height: 16),

        // Kontak
        Text(
          'Kontak (opsional)',
          style: GoogleFonts.arimo(
            fontSize: 13,
            color: const Color(0xFF0C0315),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: contactController,
                  style: GoogleFonts.arimo(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Nomor telepon atau nama kontak',
                  ),
                ),
              ),
              IconButton(
                onPressed: onPickContact,
                icon: const Icon(Icons.contact_phone, color: Color(0xFF6B5E78)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NoteField extends StatelessWidget {
  const NoteField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.arimo(fontSize: 16),
            maxLines: 4,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Tambahkan catatan penting...',
            ),
          ),
        ),
      ],
    );
  }
}
