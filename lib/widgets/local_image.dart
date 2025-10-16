import 'dart:io';

import 'package:flutter/material.dart';

/// Displays a local image file safely.
///
/// - Verifies the file exists (async) before attempting to show it to avoid
///   runtime errors when the file was removed externally.
/// - Shows a small loading placeholder while the file existence is verified
///   and until the image frame is available. This helps with large image
///   decoding delays.
class LocalImage extends StatelessWidget {
  const LocalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  Widget _defaultPlaceholder() => Container(
    color: const Color(0xFFEFEFEF),
    child: const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ph = placeholder ?? _defaultPlaceholder();
    if (path == null) {
      return SizedBox(width: width, height: height, child: ph);
    }

    final file = File(path!);
    try {
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (ctx, err, st) =>
                SizedBox(width: width, height: height, child: ph),
          ),
        );
      }
    } catch (_) {
      // fall back to async check
    }

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(width: width, height: height, child: ph);
        }
        if (!snap.hasData || snap.data != true) {
          // file missing
          return SizedBox(width: width, height: height, child: ph);
        }

        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
              if (frame == null) {
                return SizedBox(width: width, height: height, child: ph);
              }
              return child;
            },
            errorBuilder: (ctx, err, st) =>
                SizedBox(width: width, height: height, child: ph),
          ),
        );
      },
    );
  }
}
