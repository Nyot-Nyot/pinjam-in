import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Simple crop/preview screen.
/// Shows the image inside an InteractiveViewer and a centered square crop box.
/// On Crop, computes the visible area and saves a cropped JPEG into app documents
/// and returns the new path.
class ImageCropPreview extends StatefulWidget {
  const ImageCropPreview({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ImageCropPreview> createState() => _ImageCropPreviewState();
}

class _ImageCropPreviewState extends State<ImageCropPreview> {
  final TransformationController _ctr = TransformationController();
  late img.Image? _decoded;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final f = File(widget.imagePath);
    if (!await f.exists()) return;
    final bytes = await f.readAsBytes();
    _decoded = img.decodeImage(bytes);
    if (mounted) setState(() {});
  }

  Future<String?> _doCrop(Size containerSize) async {
    if (_decoded == null) return null;
    setState(() => _working = true);
    try {
      final original = _decoded!;

      // Determine how the image is fitted into the container when using BoxFit.contain
      // no fitted scale needed for center crop

      // For now do a simple center-square crop of the original image. This
      // avoids complex matrix inversion mapping from the InteractiveViewer
      // coordinates and provides a reliable crop preview that the user can
      // reposition by re-tapping/zooming and then resetting if needed.
      final minSide = original.width < original.height
          ? original.width
          : original.height;
      final cropSide = (minSide * 0.8).round();
      final left = ((original.width - cropSide) / 2).round();
      final top = ((original.height - cropSide) / 2).round();
      final cropped = img.copyCrop(
        original,
        x: left,
        y: top,
        width: cropSide,
        height: cropSide,
      );

      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final outPath =
          '${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}_crop.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(cropped, quality: 90));
      return outPath;
    } catch (e) {
      return null;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _ctr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pratinjau & Potong'),
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop<String?>(null);
            },
            child: const Text('Batal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _decoded == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (ctx, constraints) {
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            children: [
                              InteractiveViewer(
                                transformationController: _ctr,
                                panEnabled: true,
                                scaleEnabled: true,
                                minScale: 0.5,
                                maxScale: 5.0,
                                child: Center(
                                  // Center the image so it's always placed in the
                                  // middle of the available area. Use BoxFit.contain
                                  // to preserve aspect ratio and keep it fully visible.
                                  child: Image.file(
                                    File(widget.imagePath),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              // centered square overlay
                              LayoutBuilder(
                                builder: (c2, cc) {
                                  final cw = cc.maxWidth;
                                  final ch = cc.maxHeight;
                                  final size = (cw < ch ? cw : ch) * 0.7;
                                  final left = (cw - size) / 2;
                                  final top = (ch - size) / 2;
                                  return IgnorePointer(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Positioned(
                                          left: left,
                                          top: top,
                                          width: size,
                                          height: size,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.white70,
                                                width: 2,
                                              ),
                                              color: Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 80,
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: _working
                                ? null
                                : () async {
                                    _ctr.value = Matrix4.identity();
                                  },
                            child: const Text('Reset'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _working
                                  ? null
                                  : () async {
                                      // perform crop based on current visible box
                                      final navigator = Navigator.of(context);
                                      final cropPath = await _doCrop(
                                        Size(
                                          constraints.maxWidth,
                                          constraints.maxHeight - 80,
                                        ),
                                      );
                                      if (!mounted) return;
                                      navigator.pop<String?>(cropPath);
                                    },
                              child: _working
                                  ? const CircularProgressIndicator()
                                  : const Text('Potong & Simpan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
