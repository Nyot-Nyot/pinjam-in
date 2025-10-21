import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final GlobalKey _repaintKey = GlobalKey();
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
    setState(() => _working = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final ui.Image captured = await boundary.toImage(pixelRatio: dpr);
      final byteData = await captured.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();

      final full = img.decodeImage(bytes);
      if (full == null) return null;

      final logicalSize = boundary.size;
      final cw = logicalSize.width;
      final ch = logicalSize.height;
      final overlaySize = (cw < ch ? cw : ch) * 0.7;
      final left = (cw - overlaySize) / 2;
      final top = (ch - overlaySize) / 2;

      final leftPx = (left * dpr).round();
      final topPx = (top * dpr).round();
      var wPx = (overlaySize * dpr).round();
      var hPx = (overlaySize * dpr).round();

      final inset = (2.0 * dpr).round();
      final x = math.max(0, leftPx + inset);
      final y = math.max(0, topPx + inset);
      wPx = math.max(1, wPx - inset * 2);
      hPx = math.max(1, hPx - inset * 2);

      final maxW = full.width;
      final maxH = full.height;
      final cropX = math.min(x, maxW - 1);
      final cropY = math.min(y, maxH - 1);
      final cropW = math.min(wPx, maxW - cropX);
      final cropH = math.min(hPx, maxH - cropY);

      final cropped = img.copyCrop(
        full,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
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
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  transformationController: _ctr,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  minScale: 0.5,
                                  maxScale: 5.0,
                                  child: Center(
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
                                          // Top overlay (above crop box)
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            right: 0,
                                            height: top,
                                            child: Container(
                                              color: Colors.black54,
                                            ),
                                          ),
                                          // Bottom overlay (below crop box)
                                          Positioned(
                                            left: 0,
                                            top: top + size,
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              color: Colors.black54,
                                            ),
                                          ),
                                          // Left overlay (left of crop box)
                                          Positioned(
                                            left: 0,
                                            top: top,
                                            width: left,
                                            height: size,
                                            child: Container(
                                              color: Colors.black54,
                                            ),
                                          ),
                                          // Right overlay (right of crop box)
                                          Positioned(
                                            left: left + size,
                                            top: top,
                                            right: 0,
                                            height: size,
                                            child: Container(
                                              color: Colors.black54,
                                            ),
                                          ),
                                          // Crop box border (transparent inside)
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
