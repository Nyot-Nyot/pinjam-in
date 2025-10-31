import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/loan_item.dart';
import '../services/contact_service.dart';
// theme colors are used by SectionCard in add_item_helpers
import '../utils/date_helper.dart';
import '../utils/error_handler.dart';
import '../widgets/add_item_helpers.dart';
import '../widgets/date_picker_modal.dart';
import '../widgets/image_picker_section.dart';
import '../widgets/loan_form_fields.dart';

class AddItemScreen extends StatefulWidget {
  /// If [initial] is provided, the screen will be used to edit that item (fields are prefilled).
  /// If [onSave] is provided, the screen will call it with the created/updated item instead of popping.
  const AddItemScreen({
    super.key,
    this.initial,
    this.onSave,
    this.onCancel,
    this.showBackButton = false,
  });

  final LoanItem? initial;
  final ValueChanged<LoanItem>? onSave;
  final VoidCallback? onCancel;
  final bool showBackButton;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late TextEditingController _titleController;
  late TextEditingController _borrowerController;
  late TextEditingController _noteController;
  late TextEditingController _contactController;
  DateTime? _selectedDate;
  String? _pickedImagePath;
  final GlobalKey _imagePickerKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _titleError = false;
  bool _borrowerError = false;

  @override
  void initState() {
    super.initState();
    // Prefill when editing
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _borrowerController = TextEditingController(
      text: widget.initial?.borrower ?? '',
    );
    _noteController = TextEditingController(text: widget.initial?.note ?? '');
    _contactController = TextEditingController(
      text: widget.initial?.contact ?? '',
    );

    // If editing an existing item, show its image preview (validate file exists)
    _pickedImagePath = widget.initial?.imagePath;
    // Image validation handled by extracted ImagePickerSection widget.

    // Prefer an absolute dueDate if present; fall back to legacy daysRemaining.
    if (widget.initial?.dueDate != null) {
      _selectedDate = widget.initial!.dueDate!.toLocal();
    } else if (widget.initial?.daysRemaining != null) {
      _selectedDate = DateHelper.addDaysToNow(widget.initial!.daysRemaining!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _borrowerController.dispose();
    _noteController.dispose();
    _contactController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AddItemScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initial item changed (e.g. HomeScreen set _editingItem and
    // navigated to the Add page without recreating the widget), update the
    // controllers so the form shows the new item's data.
    if (oldWidget.initial?.id != widget.initial?.id) {
      _titleController.text = widget.initial?.title ?? '';
      _borrowerController.text = widget.initial?.borrower ?? '';
      _noteController.text = widget.initial?.note ?? '';
      _contactController.text = widget.initial?.contact ?? '';
      _pickedImagePath = widget.initial?.imagePath;
      if (widget.initial?.dueDate != null) {
        _selectedDate = widget.initial!.dueDate!.toLocal();
      } else if (widget.initial?.daysRemaining != null) {
        _selectedDate = DateHelper.addDaysToNow(widget.initial!.daysRemaining!);
      } else {
        _selectedDate = null;
      }
      setState(() {});
    }
  }

  // Image path validation moved to ImagePickerSection.

  void _applyPreset(int days) {
    setState(() {
      _selectedDate = DateHelper.addDaysToNow(days);
    });
  }

  // Image picker and processing moved to ImagePickerSection widget.

  // SectionCard, PresetChip and ActionButton extracted to
  // `lib/widgets/add_item_helpers.dart` to reduce file size.

  Future<void> _pickCustomDate() async {
    final initial = _selectedDate ?? DateTime.now();
    final picked = await DatePickerModal.show(
      context: context,
      initialDate: initial,
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickContact() async {
    // Delegate contact selection to ContactService so the logic is reusable
    // across screens. ContactService will show dialogs and handle permission.
    final result = await ContactService.pickContact(context);
    if (!mounted) return;
    if (result != null) {
      setState(() => _contactController.text = result);
    }
  }

  // Removed redundant private _onSave to centralize save logic in the button handler

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.initial != null;
    // Choose indices so the date picker and note boxes have different
    // pastel backgrounds when in Add vs Edit mode.
    final int dateCardIndex = isEdit ? 1 : 3;
    final int noteCardIndex = isEdit ? 2 : 0;

    final selectedDateLabel = _selectedDate == null
        ? 'Belum ada tanggal'
        : DateHelper.formatDate(_selectedDate!);

    return Scaffold(
      backgroundColor: const Color(0xFFF6EFFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.initial == null ? 'Catat Pinjaman' : 'Edit Pinjaman',
          style: GoogleFonts.arimo(color: const Color(0xFF0C0315)),
        ),
        // remove the leading/back button as requested
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0C0315)),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            SectionCard(
              index: 0,
              child: ImagePickerSection(
                key: _imagePickerKey,
                initialPath: widget.initial?.imagePath,
                onChanged: (p) => setState(() => _pickedImagePath = p),
              ),
            ),

            const SizedBox(height: 12),
            SectionCard(
              index: 1,
              child: TitleField(
                controller: _titleController,
                error: _titleError,
              ),
            ),

            const SizedBox(height: 16),
            // Combined: Nama Peminjam + Kontak
            SectionCard(
              index: 2,
              child: BorrowerContactFields(
                borrowerController: _borrowerController,
                contactController: _contactController,
                borrowerError: _borrowerError,
                onPickContact: _pickContact,
              ),
            ),

            const SizedBox(height: 12),
            SectionCard(
              index: dateCardIndex,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal Target Kembali',
                    style: GoogleFonts.arimo(
                      fontSize: 14,
                      color: const Color(0xFF0C0315),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // white rounded date display + calendar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dikembalikan pada',
                                style: GoogleFonts.arimo(
                                  fontSize: 12,
                                  color: const Color(0xFF4A3D5C),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedDateLabel,
                                style: GoogleFonts.arimo(
                                  fontSize: 16,
                                  color: const Color(0xFF0C0315),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Hero(
                          tag: 'date-picker-hero',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8530E4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: IconButton(
                                onPressed: _pickCustomDate,
                                icon: const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2x2 presets
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.8,
                    children: [
                      PresetChip(label: '3 Hari', onTap: () => _applyPreset(3)),
                      PresetChip(
                        label: '1 Minggu',
                        onTap: () => _applyPreset(7),
                      ),
                      PresetChip(
                        label: '2 Minggu',
                        onTap: () => _applyPreset(14),
                      ),
                      PresetChip(
                        label: '1 Bulan',
                        onTap: () => _applyPreset(30),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: 'Pilih Tanggal',
                          onTap: _pickCustomDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionButton(
                          label: 'Tanpa Batas',
                          onTap: () {
                            setState(() => _selectedDate = null);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            SectionCard(
              index: noteCardIndex,
              child: NoteField(controller: _noteController),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6EFFD),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      // If embedded (onSave provided) delegate cancellation to parent
                      if (widget.onSave != null) {
                        if (widget.onCancel != null) {
                          widget.onCancel!();
                        }
                        return;
                      }
                      Navigator.of(context).pop();
                    },
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
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      // If parent provided onSave (embedded), call it instead of popping the route
                      final title = _titleController.text.trim();
                      final borrower = _borrowerController.text.trim();

                      setState(() {
                        _titleError = title.isEmpty;
                        _borrowerError = borrower.isEmpty;
                      });

                      if (_titleError || _borrowerError) {
                        ErrorHandler.showError(
                          context,
                          'Periksa field wajib yang diberi tanda.',
                        );
                        _scrollController.animateTo(
                          0,
                          duration: AppConstants.quickTransitionDuration,
                          curve: Curves.ease,
                        );
                        return;
                      }

                      final int? daysRemaining = _selectedDate != null
                          ? DateHelper.daysUntil(_selectedDate!)
                          : null;

                      // Capture navigator and onSave callback before any await so
                      // we don't use BuildContext across an async gap.
                      final onSaveCb = widget.onSave;
                      final navigator = Navigator.of(context);

                      // If an image was picked, ask the ImagePickerSection to
                      // process & persist a resized copy and return the saved path.
                      String? finalImagePath = _pickedImagePath;
                      if (_pickedImagePath != null) {
                        finalImagePath =
                            await (_imagePickerKey.currentState as dynamic)
                                ?.processAndSaveImage() ??
                            _pickedImagePath;
                        if (!mounted) return;
                      }

                      final now = DateTime.now().toUtc();
                      final newItem = LoanItem(
                        id: widget.initial?.id ?? const Uuid().v4(),
                        title: title,
                        borrower: borrower,
                        daysRemaining: daysRemaining,
                        createdAt: widget.initial?.createdAt ?? now,
                        dueDate:
                            _selectedDate, // Keep as local date, don't convert to UTC
                        returnedAt: widget.initial?.returnedAt,
                        note: _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                        contact: _contactController.text.trim().isEmpty
                            ? null
                            : _contactController.text.trim(),
                        imagePath: finalImagePath,
                        imageUrl: widget.initial?.imageUrl,
                        ownerId: widget.initial?.ownerId,
                        status: widget.initial?.status ?? 'active',
                      );

                      if (onSaveCb != null) {
                        onSaveCb(newItem);
                        return;
                      }

                      navigator.pop<LoanItem>(newItem);
                    },
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

  // PresetChip and ActionButton moved to `lib/widgets/add_item_helpers.dart`.
}
