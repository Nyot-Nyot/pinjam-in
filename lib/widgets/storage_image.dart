import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/persistence_service.dart';

/// Widget to display an image from Supabase Storage using signed URLs.
/// Handles both local images (via imagePath) and remote images (via imageUrl).
class StorageImage extends StatefulWidget {
  final String? imagePath;
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final PersistenceService persistence;

  const StorageImage({
    super.key,
    this.imagePath,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    required this.persistence,
  });

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  String? _signedUrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if imageUrl changed
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    // If we have a local path, no need to fetch signed URL
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      return;
    }

    // If no imageUrl, nothing to load
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return;
    }

    debugPrint('StorageImage: Loading URL: ${widget.imageUrl}');

    // If the imageUrl already looks like a proper URL (absolute), just use it
    // without asking persistence for a signed url. This handles the case where
    // callers pass a full URL. We validate that the URI has a scheme and host
    // to avoid passing relative paths to network loaders which crash.
    try {
      final u = Uri.tryParse(widget.imageUrl ?? '');
      if (u != null &&
          (u.scheme == 'http' || u.scheme == 'https') &&
          u.host.isNotEmpty) {
        setState(() {
          _signedUrl = widget.imageUrl;
          _loading = false;
        });
        return;
      }
    } catch (_) {}

    // Always go through getSignedUrl for Supabase Storage URLs
    // This handles both public and private buckets correctly
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try to detect any persistence that exposes a getSignedUrl method
      final ps = widget.persistence;
      try {
        final dyn = ps as dynamic;
        // Try to obtain signed url first (works for private buckets)
        try {
          final fn = dyn.getSignedUrl;
          if (fn != null && fn is Function) {
            debugPrint(
              'StorageImage: Calling getSignedUrl via persistence instance',
            );
            final signedUrl = await dyn.getSignedUrl(widget.imageUrl!);
            debugPrint('StorageImage: Got signed URL: $signedUrl');
            if (signedUrl != null && mounted) {
              setState(() {
                _signedUrl = signedUrl;
                _loading = false;
              });
            }
            // If signedUrl was found - return, otherwise continue to try public URL
            if (signedUrl != null) return;
          }
        } catch (_) {}

        // If signed url not available, try to obtain a public URL (for public buckets)
        try {
          final pubFn = dyn.getPublicUrl;
          if (pubFn != null && pubFn is Function) {
            debugPrint(
              'StorageImage: Calling getPublicUrl via persistence instance',
            );
            final pub = await dyn.getPublicUrl(widget.imageUrl!);
            debugPrint('StorageImage: Got public URL: $pub');
            if (pub != null && mounted) {
              setState(() {
                _signedUrl = pub;
                _loading = false;
              });
            }
            if (pub != null) return;
          }
        } catch (_) {}
      } catch (_) {
        // not present or not callable — continue to fallback below
      }

      // Not using a persistence with getSignedUrl and/or the provided URL is a
      // relative storage path (e.g. 'user_id/photo.jpg'). In this case do NOT
      // pass the raw path to the network loader (it will crash with "No host
      // specified"). Instead, fall back to placeholder UI by leaving
      // _signedUrl null.
      if (mounted) {
        setState(() {
          _signedUrl = null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('StorageImage: Error loading signed URL: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Priority 1: Local image path
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      // Use ResizeImage to avoid decoding very large images at full size on the
      // UI thread. When target width/height are provided, wrap the FileImage
      // in a ResizeImage so the engine can produce a smaller decoded image.
      final file = File(widget.imagePath!);
      final baseProvider = FileImage(file);
      ImageProvider provider = baseProvider;
      try {
        final int? w = widget.width?.toInt();
        final int? h = widget.height?.toInt();
        if (w != null || h != null) {
          provider = ResizeImage(baseProvider, width: w, height: h);
        }
      } catch (_) {
        provider = baseProvider;
      }

      return Image(
        image: provider,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(error.toString());
        },
      );
    }

    // Priority 2: Signed URL from Storage
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildPlaceholder(_error);
    }

    if (_signedUrl != null && _signedUrl!.isNotEmpty) {
      // Special-case data URIs: use Image.memory to render inline base64 images.
      if (_signedUrl!.startsWith('data:')) {
        final parts = _signedUrl!.split(',');
        if (parts.length == 2) {
          try {
            final payload = parts[1];
            final bytes = base64Decode(payload);
            return Image.memory(
              bytes,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              errorBuilder: (context, error, stack) =>
                  _buildPlaceholder(error.toString()),
            );
          } catch (e) {
            // Fallthrough to network loader as fallback
          }
        }
      }
      return CachedNetworkImage(
        imageUrl: _signedUrl!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (context, url) => SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) =>
            _buildPlaceholder(error.toString()),
      );
    }

    // No image available
    return _buildPlaceholder(null);
  }

  Widget _buildPlaceholder(String? error) {
    // Calculate appropriate icon size based on container size
    final double iconSize = widget.width != null && widget.height != null
        ? (widget.width! < widget.height! ? widget.width! : widget.height!) *
              0.5
        : 48.0;
    final clampedIconSize = iconSize.clamp(24.0, 48.0);

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: Colors.grey[600],
              size: clampedIconSize,
            ),
            if (error != null && (widget.height == null || widget.height! > 80))
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Allow a reload retry button when image fails to load
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Retry',
                        onPressed: () {
                          _loadSignedUrl();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
