import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/image_crop_preview.dart';
import '../utils/date_helper.dart';
import '../utils/error_handler.dart';

/// A self-contained image picker + preview section extracted from AddItemScreen.
///
/// Exposes `processAndSaveImage()` on its State (call via GlobalKey) which will
/// return a persisted/resized image path or the original picked path.
class ImagePickerSection extends StatefulWidget {
  const ImagePickerSection({
    super.key,
    this.initialPath,
    required this.onChanged,
  });

  final String? initialPath;
  final ValueChanged<String?> onChanged;

  @override
  State<ImagePickerSection> createState() => _ImagePickerSectionState();
}

class _ImagePickerSectionState extends State<ImagePickerSection> {
  String? _pickedImagePath;

  @override
  void initState() {
    super.initState();
    _pickedImagePath = widget.initialPath;
    if (_pickedImagePath != null) _validatePickedImagePath(_pickedImagePath!);
  }

  Future<void> _validatePickedImagePath(String path) async {
    try {
      final f = File(path);
      final exists = await f.exists();
      if (!exists && mounted) {
        setState(() => _pickedImagePath = null);
        widget.onChanged(null);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pickedImagePath = null);
        widget.onChanged(null);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final localContext = context;
    final navigator = Navigator.of(localContext);
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
        );
        if (image == null) return;
        if (!mounted) return;
        final picked = image.path;
        final result = await navigator.push<String?>(
          MaterialPageRoute(
            builder: (_) => ImageCropPreview(imagePath: picked),
          ),
        );
        if (!mounted) return;
        if (result != null) {
          await _maybeDeletePersisted(_pickedImagePath);
          setState(() => _pickedImagePath = result);
          widget.onChanged(result);
        }
        return;
      }

      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      if (!mounted) return;
      final result = await navigator.push<String?>(
        MaterialPageRoute(builder: (_) => ImageCropPreview(imagePath: path)),
      );
      if (!mounted) return;
      if (result != null) {
        await _maybeDeletePersisted(_pickedImagePath);
        setState(() => _pickedImagePath = result);
        widget.onChanged(result);
      }
    } catch (e) {
      final err = e.toString();
      if (Platform.isLinux && err.toLowerCase().contains('zenity')) {
        if (!mounted) return;
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
                  final navigator2 = Navigator.of(ctx);
                  await Clipboard.setData(
                    const ClipboardData(text: 'sudo apt install zenity'),
                  );
                  if (!ctx.mounted) return;
                  navigator2.pop();
                  ErrorHandler.showInfo(
                    ctx,
                    'Perintah instalasi disalin ke clipboard',
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
      ErrorHandler.showError(context, 'Gagal memilih foto: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    final navigator = Navigator.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
      );
      if (image == null) return;
      if (!mounted) return;
      final picked = image.path;
      final result = await navigator.push<String?>(
        MaterialPageRoute(builder: (_) => ImageCropPreview(imagePath: picked)),
      );
      if (!mounted) return;
      if (result != null) {
        await _maybeDeletePersisted(_pickedImagePath);
        setState(() => _pickedImagePath = result);
        widget.onChanged(result);
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, 'Gagal mengambil foto: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final navigator = Navigator.of(context);
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
        );
        if (image == null) return;
        if (!mounted) return;
        final picked = image.path;
        final result = await navigator.push<String?>(
          MaterialPageRoute(
            builder: (_) => ImageCropPreview(imagePath: picked),
          ),
        );
        if (!mounted) return;
        setState(() => _pickedImagePath = result ?? picked);
        widget.onChanged(_pickedImagePath);
        return;
      }

      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.first.path;
      if (path == null) return;
      if (!mounted) return;
      final result = await navigator.push<String?>(
        MaterialPageRoute(builder: (_) => ImageCropPreview(imagePath: path)),
      );
      if (!mounted) return;
      await _maybeDeletePersisted(_pickedImagePath);
      setState(() => _pickedImagePath = result ?? path);
      widget.onChanged(_pickedImagePath);
    } catch (e) {
      final err = e.toString();
      if (Platform.isLinux && err.toLowerCase().contains('zenity')) {
        if (!mounted) return;
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
                  await Clipboard.setData(
                    const ClipboardData(text: 'sudo apt install zenity'),
                  );
                  if (!ctx.mounted) return;
                  navigator.pop();
                  ErrorHandler.showInfo(
                    ctx,
                    'Perintah instalasi disalin ke clipboard',
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
      ErrorHandler.showError(context, 'Gagal memilih foto: $e');
    }
  }

  Future<void> _showPhotoOptions() async {
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

  /// Resize and persist the currently picked image into the app documents/images
  /// folder. Returns the saved path or original picked path on failure.
  Future<String?> processAndSaveImage() async {
    if (_pickedImagePath == null) return null;
    try {
      final original = File(_pickedImagePath!);
      if (!await original.exists()) return _pickedImagePath;
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
      final outPath = '${imagesDir.path}/${DateHelper.timestamp()}.jpg';
      final jpg = img.encodeJpg(processed, quality: 85);
      final outFile = File(outPath);
      await outFile.writeAsBytes(jpg);
      return outPath;
    } catch (_) {
      return _pickedImagePath;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Foto Barang', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Container(
              height: 128,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: const Color(0xFFE6DBF8), width: 1.0),
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
                        style: TextStyle(color: Colors.grey.shade700),
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
                              _maybeDeletePersisted(_pickedImagePath);
                              setState(() => _pickedImagePath = null);
                              widget.onChanged(null);
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
    );
  }
}
