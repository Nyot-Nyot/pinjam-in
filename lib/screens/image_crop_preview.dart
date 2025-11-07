import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

/// Runs in a background isolate: decode the provided PNG bytes, clamp crop
/// rect against image bounds, crop and encode as JPEG. Returns encoded JPG
/// bytes or null on failure.
Uint8List? _cropAndEncodeJpg(Map<String, dynamic> params) {
  try {
    final pngBytes = params['pngBytes'] as Uint8List;
    final x = params['x'] as int;
    final y = params['y'] as int;
    final w = params['w'] as int;
    final h = params['h'] as int;
    final quality = params['quality'] as int? ?? 90;

    final full = img.decodeImage(pngBytes);
    if (full == null) return null;

    final maxW = full.width;
    final maxH = full.height;
    final cropX = math.min(x, maxW - 1);
    final cropY = math.min(y, maxH - 1);
    final cropW = math.min(w, maxW - cropX);
    final cropH = math.min(h, maxH - cropY);

    final cropped = img.copyCrop(
      full,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
  } catch (_) {
    return null;
  }
}

class _ImageCropPreviewState extends State<ImageCropPreview> {
  final TransformationController _ctr = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _isLoaded = false;
  bool _working = false;
  double _overlayScale = 0.7; // 0.7 by default; user can toggle to 1.0 to use full visible image

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final f = File(widget.imagePath);
    if (!await f.exists()) return;
    // Avoid decoding the image on the main isolate — Image.file will handle
    // rendering; we only need to know the file is available.
    _isLoaded = true;
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

      // Compute logical overlay/crop rectangle in pixels (based on the
      // RepaintBoundary logical size and devicePixelRatio). Then offload the
      // heavy decoding + cropping work to a background isolate via `compute`.
      final logicalSize = boundary.size;
      final cw = logicalSize.width;
      final ch = logicalSize.height;
  final overlaySize = (cw < ch ? cw : ch) * _overlayScale;
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

      // Offload cropping: send captured PNG bytes and the requested crop rect
      // to an isolate which will decode, clamp, crop and encode JPEG bytes.
      final params = <String, dynamic>{
        'pngBytes': bytes,
        'x': x,
        'y': y,
        'w': wPx,
        'h': hPx,
        'quality': 90,
      };

      final Uint8List? outJpg = await compute(_cropAndEncodeJpg, params);
      if (outJpg == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/images');
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
      final outPath =
          '${imagesDir.path}/${DateTime.now().millisecondsSinceEpoch}_crop.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(outJpg);
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
      body: !_isLoaded
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
                                    final size = (cw < ch ? cw : ch) * _overlayScale;
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
                          const SizedBox(width: 8),
                          // Use original photo (bypass crop) — helpful when subject is too
                          // large and would be cut by the square crop box.
                          TextButton.icon(
                            onPressed: _working
                                ? null
                                : () {
                                    Navigator.of(context).pop<String?>(
                                      widget.imagePath,
                                    );
                                  },
                            icon: const Icon(Icons.photo),
                            label: const Text('Gunakan Foto Asli'),
                          ),
                          const SizedBox(width: 8),
                          // Toggle overlay scale between compact (0.7) and full (1.0)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _overlayScale = (_overlayScale == 1.0) ? 0.7 : 1.0;
                              });
                            },
                            tooltip: _overlayScale == 1.0
                                ? 'Kecilkan area potong'
                                : 'Perbesar area potong ke ukuran penuh',
                            icon: Icon(
                              _overlayScale == 1.0
                                  ? Icons.crop_square_outlined
                                  : Icons.crop_square,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
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
