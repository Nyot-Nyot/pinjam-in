import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/persistence_service.dart';
import '../services/supabase_persistence.dart';

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

    print('StorageImage: Loading URL: ${widget.imageUrl}');

    // Always go through getSignedUrl for Supabase Storage URLs
    // This handles both public and private buckets correctly
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.persistence is SupabasePersistence) {
        print('StorageImage: Calling getSignedUrl');
        final signedUrl = await (widget.persistence as SupabasePersistence)
            .getSignedUrl(widget.imageUrl!);
        print('StorageImage: Got signed URL: $signedUrl');
        if (mounted) {
          setState(() {
            _signedUrl = signedUrl;
            _loading = false;
          });
        }
      } else {
        // Not using Supabase, just use the URL directly
        if (mounted) {
          setState(() {
            _signedUrl = widget.imageUrl;
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('StorageImage: Error loading signed URL: $e');
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
                  child: Text(
                    error,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
