import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/loan_item.dart';
import 'image_crop_preview.dart';

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

    if (widget.initial?.daysRemaining != null) {
      _selectedDate = DateTime.now().add(
        Duration(days: widget.initial!.daysRemaining!),
      );
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
      if (widget.initial?.daysRemaining != null) {
        _selectedDate = DateTime.now().add(
          Duration(days: widget.initial!.daysRemaining!),
        );
      } else {
        _selectedDate = null;
      }
      setState(() {});
    }
  }

  void _applyPreset(int days) {
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _pickPhoto() async {
    final localContext = context;
    try {
      // On mobile, open camera directly.
      if (Platform.isAndroid || Platform.isIOS) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
        );
        if (image == null) return;
        if (!mounted) return;
        // Open crop preview and use returned path if user confirmed a crop.
        final picked = image.path;
        final navigator = Navigator.of(localContext);
        final result = await navigator.push<String?>(
          MaterialPageRoute(
            builder: (_) => ImageCropPreview(imagePath: picked),
          ),
        );
        if (!mounted) return;
        if (result != null) {
          await _maybeDeletePersisted(_pickedImagePath);
          setState(() => _pickedImagePath = result);
        }
        return;
      }

      // Desktop / fallback -> file picker
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final result = await navigator.push<String?>(
        MaterialPageRoute(builder: (_) => ImageCropPreview(imagePath: path)),
      );
      if (!mounted) return;
      if (result != null) {
        await _maybeDeletePersisted(_pickedImagePath);
        setState(() => _pickedImagePath = result);
      }
    } catch (e) {
      final err = e.toString();
      // On some Linux distributions FilePicker relies on zenity. If it's
      // missing the native error message references 'zenity'. Show a
      // helpful dialog with install instructions instead of the raw error.
      if (Platform.isLinux && err.toLowerCase().contains('zenity')) {
        if (!mounted) return;
        showDialog<void>(
          context: localContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Picker foto tidak tersedia'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pilih foto gagal karena utilitas "zenity" tidak ditemukan di sistem.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Instal salah satu dari perintah berikut sesuai distro Anda dan jalankan ulang aplikasi:',
                  ),
                  SizedBox(height: 8),
                  Text('• Debian / Ubuntu: sudo apt install zenity'),
                  Text('• Fedora: sudo dnf install zenity'),
                  Text('• Arch: sudo pacman -S zenity'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(ctx);
                  await Clipboard.setData(
                    const ClipboardData(text: 'sudo apt install zenity'),
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Perintah instalasi disalin ke clipboard'),
                    ),
                  );
                },
                child: const Text('Salin perintah apt'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
      );
      if (image == null) return;
      if (!mounted) return;
      final picked = image.path;
      final navigator = Navigator.of(context);
      final result = await navigator.push<String?>(
        MaterialPageRoute(builder: (_) => ImageCropPreview(imagePath: picked)),
      );
      if (!mounted) return;
      if (result != null) {
        await _maybeDeletePersisted(_pickedImagePath);
        setState(() => _pickedImagePath = result);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      // On mobile, prefer image_picker gallery for a nicer UI
      if (Platform.isAndroid || Platform.isIOS) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
        );
        if (image == null) return;
        if (!mounted) return;
        final picked = image.path;
        final navigator = Navigator.of(context);
        final result = await navigator.push<String?>(
          MaterialPageRoute(
            builder: (_) => ImageCropPreview(imagePath: picked),
          ),
        );
        if (!mounted) return;
        setState(() => _pickedImagePath = result ?? picked);
        return;
      }

      // Desktop fallback
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final result = await navigator.push<String?>(
        MaterialPageRoute(builder: (_) => ImageCropPreview(imagePath: path)),
      );
      if (!mounted) return;
      await _maybeDeletePersisted(_pickedImagePath);
      setState(() => _pickedImagePath = result ?? path);
    } catch (e) {
      final err = e.toString();
      if (Platform.isLinux && err.toLowerCase().contains('zenity')) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Picker foto tidak tersedia'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Pilih foto gagal karena utilitas "zenity" tidak ditemukan di sistem.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Instal salah satu dari perintah berikut sesuai distro Anda dan jalankan ulang aplikasi:',
                  ),
                  SizedBox(height: 8),
                  Text('• Debian / Ubuntu: sudo apt install zenity'),
                  Text('• Fedora: sudo dnf install zenity'),
                  Text('• Arch: sudo pacman -S zenity'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(ctx);
                  await Clipboard.setData(
                    const ClipboardData(text: 'sudo apt install zenity'),
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Perintah instalasi disalin ke clipboard'),
                    ),
                  );
                },
                child: const Text('Salin perintah apt'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $e')));
    }
  }

  Future<void> _showPhotoOptions() async {
    // On desktop simply use the existing picker path
    if (!(Platform.isAndroid || Platform.isIOS)) {
      await _pickPhoto();
      return;
    }

    final result = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
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

    if (result == 'camera') {
      await _pickFromCamera();
    } else if (result == 'gallery') {
      await _pickFromGallery();
    }
  }

  /// If a photo was picked, resize it to a reasonable max width and save a
  /// copy into the app documents directory. Returns the saved file path or
  /// the original path if processing fails.
  Future<String?> _processAndSaveImage() async {
    if (_pickedImagePath == null) return null;
    try {
      final original = File(_pickedImagePath!);
      if (!await original.exists()) return _pickedImagePath;
      // If the picked image is already in the app's images folder, return it
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (_pickedImagePath!.startsWith(imagesDir.path)) return _pickedImagePath;
      final bytes = await original.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return _pickedImagePath;

      const maxWidth = 1200;
      final processed = decoded.width > maxWidth
          ? img.copyResize(decoded, width: maxWidth)
          : decoded;

      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final outPath =
          '${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final jpg = img.encodeJpg(processed, quality: 85);
      final outFile = File(outPath);
      await outFile.writeAsBytes(jpg);
      return outPath;
    } catch (_) {
      // If anything fails, fall back to the original picked path so saving
      // still works even when processing isn't available.
      return _pickedImagePath;
    }
  }

  /// If the provided path points to a persisted app image, delete it.
  Future<void> _maybeDeletePersisted(String? path) async {
    if (path == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (path.startsWith(imagesDir.path)) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  Color _pastelForIndex(int i) {
    // even stronger, more saturated pastel palette for clearer sections
    final colors = [
      const Color(0xFFFF95B8), // vivid warm pink
      const Color(0xFF7FD8FF), // vivid ice blue
      const Color(0xFFFFCE6B), // bright peach/yellow
      const Color(0xFFB78CFF), // stronger lavender
      const Color(0xFF79F0B0), // bright mint
    ];
    return colors[i % colors.length];
  }

  Widget _sectionCard({required Widget child, required int index}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pastelForIndex(index),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Future<void> _pickCustomDate() async {
    // Simpler approach using CupertinoPicker per column for reliability.
    final now = DateTime.now();
    final initial = _selectedDate ?? now;

    int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

    final startYear = initial.year - 20;
    final yearCount = 41; // cover startYear .. startYear+40

    int curDay = initial.day;
    int curMonth = initial.month;
    int curYear = initial.year;

    // We'll use a custom dialog so we can control the transition (slide up/down)
    // and implement debounced haptic feedback when each wheel selection settles.
    final FixedExtentScrollController dayController =
        FixedExtentScrollController(initialItem: initial.day - 1);
    final FixedExtentScrollController monthController =
        FixedExtentScrollController(initialItem: initial.month - 1);
    final FixedExtentScrollController yearController =
        FixedExtentScrollController(initialItem: initial.year - startYear);

    Timer? dayDebounce;
    Timer? monthDebounce;
    Timer? yearDebounce;

    void scheduleHaptic(
      Timer? Function() getTimer,
      void Function(Timer?) setTimer,
    ) {
      // cancel previous then schedule
      final t = getTimer();
      t?.cancel();
      final newT = Timer(const Duration(milliseconds: 120), () {
        HapticFeedback.selectionClick();
      });
      setTimer(newT);
    }

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Pilih Tanggal Pengembalian',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (ctx, anim1, anim2) {
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(12),
                    height: 360,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBE1F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // small drag handle
                        Center(
                          child: Container(
                            width: 48,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9CCE8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pilih Tanggal Pengembalian',
                              style: GoogleFonts.arimo(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0C0315),
                              ).copyWith(decoration: TextDecoration.none),
                            ),
                            // shared element from calendar icon -> modal
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
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Scroll untuk memilih tanggal',
                          style: GoogleFonts.arimo(
                            fontSize: 14,
                            color: const Color(0xFF4A3D5C),
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: Row(
                            children: [
                              // Day
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: dayController,
                                  itemExtent: 36,
                                  onSelectedItemChanged: (i) {
                                    setModalState(() => curDay = i + 1);
                                    scheduleHaptic(
                                      () => dayDebounce,
                                      (t) => dayDebounce = t,
                                    );
                                  },
                                  childCount: 31,
                                  itemBuilder: (context, i) {
                                    final isCenter = (i + 1) == curDay;
                                    return Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: GoogleFonts.arimo(
                                          fontSize: isCenter ? 20 : 16,
                                          color: isCenter
                                              ? const Color(0xFF8530E4)
                                              : const Color(0x660C0315),
                                          fontWeight: isCenter
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Month
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: monthController,
                                  itemExtent: 36,
                                  onSelectedItemChanged: (i) {
                                    setModalState(() => curMonth = i + 1);
                                    scheduleHaptic(
                                      () => monthDebounce,
                                      (t) => monthDebounce = t,
                                    );
                                  },
                                  childCount: 12,
                                  itemBuilder: (context, i) {
                                    final name = _monthName(i + 1);
                                    final isCenter = (i + 1) == curMonth;
                                    return Center(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.arimo(
                                          fontSize: isCenter ? 18 : 14,
                                          color: isCenter
                                              ? const Color(0xFF8530E4)
                                              : const Color(0x660C0315),
                                          fontWeight: isCenter
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Year
                              Expanded(
                                child: CupertinoPicker.builder(
                                  scrollController: yearController,
                                  itemExtent: 36,
                                  onSelectedItemChanged: (i) {
                                    setModalState(
                                      () => curYear = startYear + i,
                                    );
                                    scheduleHaptic(
                                      () => yearDebounce,
                                      (t) => yearDebounce = t,
                                    );
                                  },
                                  childCount: yearCount,
                                  itemBuilder: (context, i) {
                                    final y = startYear + i;
                                    final isCenter = y == curYear;
                                    return Center(
                                      child: Text(
                                        '$y',
                                        style: GoogleFonts.arimo(
                                          fontSize: isCenter ? 18 : 14,
                                          color: isCenter
                                              ? const Color(0xFF8530E4)
                                              : const Color(0x660C0315),
                                          fontWeight: isCenter
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Batal memilih tanggal',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => Navigator.of(ctx).pop(),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD9CCE8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Batal',
                                          style:
                                              GoogleFonts.arimo(
                                                color: const Color(0xFF0C0315),
                                                fontSize: 16,
                                              ).copyWith(
                                                decoration: TextDecoration.none,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: 'Konfirmasi tanggal',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      // clamp day to selected month/year
                                      final maxD = daysInMonth(
                                        curYear,
                                        curMonth,
                                      );
                                      final selDay = curDay.clamp(1, maxD);
                                      final picked = DateTime(
                                        curYear,
                                        curMonth,
                                        selDay,
                                      );
                                      HapticFeedback.mediumImpact();
                                      Navigator.of(ctx).pop();
                                      if (!mounted) return;
                                      setState(() => _selectedDate = picked);
                                    },
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8530E4),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Konfirmasi',
                                          style:
                                              GoogleFonts.arimo(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ).copyWith(
                                                decoration: TextDecoration.none,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        transitionBuilder: (ctx, anim, secAnim, child) {
          // use a slightly springy curve for a friendlier feel
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutBack,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
    } finally {
      dayDebounce?.cancel();
      monthDebounce?.cancel();
      yearDebounce?.cancel();
      dayController.dispose();
      monthController.dispose();
      yearController.dispose();
    }
  }

  Future<void> _pickContact() async {
    try {
      final permitted = await FlutterContacts.requestPermission();
      if (!mounted) return;
      if (!permitted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin kontak ditolak')));
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return;
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada kontak di perangkat')),
        );
        return;
      }

      final choice = await showDialog<Contact?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Pilih Kontak'),
          children: contacts.take(20).map((c) {
            final subtitle = c.phones.isNotEmpty ? c.phones.first.number : '';
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
        final display = name.isNotEmpty ? '$name • $phone' : phone;
        setState(() {
          _contactController.text = display;
        });
      }
    } catch (e) {
      if (e is MissingPluginException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Picker kontak tidak tersedia pada build saat ini. Jalankan ulang aplikasi di perangkat mobile.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memilih kontak: $e')));
      }
    }
  }

  // Removed redundant private _onSave to centralize save logic in the button handler

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = _selectedDate == null
        ? 'Belum ada tanggal'
        : '${_selectedDate!.day} ${_monthName(_selectedDate!.month)} ${_selectedDate!.year}';

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
            _sectionCard(
              index: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto Barang',
                    style: GoogleFonts.arimo(
                      fontSize: 14,
                      color: const Color(0xFF0C0315),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showPhotoOptions,
                    child: Container(
                      height: 128,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: const Color(0xFFE6DBF8),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _pickedImagePath == null
                          ? Center(
                              child: Text(
                                'Tambah Foto',
                                style: GoogleFonts.arimo(
                                  color: const Color(0xFF4A3D5C),
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(_pickedImagePath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 128,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _pickedImagePath = null);
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 18,
                                      ),
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

            const SizedBox(height: 12),
            _sectionCard(
              index: 1,
              child: Column(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: TextField(
                      controller: _titleController,
                      style: GoogleFonts.arimo(fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Contoh: Power Bank Hitam',
                      ),
                    ),
                  ),
                  if (_titleError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Nama barang wajib diisi',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _sectionCard(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nama Peminjam *',
                    style: GoogleFonts.arimo(
                      fontSize: 14,
                      color: const Color(0xFF0C0315),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: TextField(
                      controller: _borrowerController,
                      style: GoogleFonts.arimo(fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Contoh: Budi Santoso',
                      ),
                    ),
                  ),
                  if (_borrowerError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Nama peminjam wajib diisi',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _sectionCard(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                          onPressed: _pickContact,
                          icon: const Icon(
                            Icons.contact_phone,
                            color: Color(0xFF6B5E78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _sectionCard(
              index: 4,
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
                      _presetChip('3 Hari', () => _applyPreset(3)),
                      _presetChip('1 Minggu', () => _applyPreset(7)),
                      _presetChip('2 Minggu', () => _applyPreset(14)),
                      _presetChip('1 Bulan', () => _applyPreset(30)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _actionButton('Pilih Tanggal', _pickCustomDate),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton('Tanpa Batas', () {
                          setState(() => _selectedDate = null);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _sectionCard(
              index: 5,
              child: Column(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                ],
              ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Periksa field wajib yang diberi tanda.',
                            ),
                          ),
                        );
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        );
                        return;
                      }

                      final int? daysRemaining = _selectedDate == null
                          ? null
                          : _selectedDate!.difference(DateTime.now()).inDays;

                      // Capture navigator and onSave callback before any await so
                      // we don't use BuildContext across an async gap.
                      final onSaveCb = widget.onSave;
                      final navigator = Navigator.of(context);

                      // If an image was picked, process & persist a resized copy
                      String? finalImagePath = _pickedImagePath;
                      if (_pickedImagePath != null) {
                        finalImagePath = await _processAndSaveImage();
                        if (!mounted) return;
                      }

                      final newItem = LoanItem(
                        id:
                            widget.initial?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        borrower: borrower,
                        daysRemaining: daysRemaining,
                        note: _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                        contact: _contactController.text.trim().isEmpty
                            ? null
                            : _contactController.text.trim(),
                        imagePath: finalImagePath,
                        color:
                            widget.initial?.color ??
                            LoanItem.pastelForId(
                              widget.initial?.id ??
                                  DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                            ),
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

  Widget _presetChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6D9F6)),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.arimo(
            color: const Color(0xFF4A3D5C),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6D9F6)),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.arimo(
          color: const Color(0xFF0C0315),
          fontWeight: FontWeight.w600,
        ),
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
