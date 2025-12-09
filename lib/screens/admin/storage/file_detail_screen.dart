import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/screens/admin/admin_layout.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/storage_service.dart';
import 'package:pinjam_in/widgets/admin/breadcrumbs.dart';
import 'package:pinjam_in/widgets/storage_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// FileDetailScreen shows metadata and preview for a single storage file.
class FileDetailScreen extends StatefulWidget {
  final String? filePath;
  final Map<String, dynamic>? fileData;
  final bool wrapWithAdminLayout;
  final StorageService? storageService;
  final AdminService? adminService;

  const FileDetailScreen({
    super.key,
    this.filePath,
    this.fileData,
    this.wrapWithAdminLayout = true,
    this.storageService,
    this.adminService,
  });

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _file;

  late final StorageService _svc;
  late final AdminService _adminSvc;

  @override
  void initState() {
    super.initState();
    _svc = widget.storageService ?? StorageService.instance;
    _adminSvc = widget.adminService ?? AdminService.instance;
    if (widget.fileData != null) {
      _file = widget.fileData;
      _isLoading = false;
    } else {
      _loadFileDetails();
    }
  }

  Future<void> _loadFileDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final path = widget.filePath;
      if (path == null || path.isEmpty) {
        setState(() {
          _file = null;
          _isLoading = false;
        });
        return;
      }
      final rows = await _svc.listFiles(limit: 1, offset: 0, search: path);
      Map<String, dynamic>? found;
      for (final r in rows) {
        if ((r['name'] ?? '').toString() == path) {
          found = r;
          break;
        }
      }
      setState(() {
        _file = found ?? (rows.isNotEmpty ? rows.first : null);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    final path = _file?['name'] as String?;
    if (path == null || path.isEmpty) return;
    bool clearRelated = true;
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Delete file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Delete "$path" from storage? This cannot be undone.'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: clearRelated,
                onChanged: (v) => setState(() => clearRelated = v ?? false),
                title: const Text('Clear related item photo_url fields'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await _adminSvc.deleteStorageObjectAndClearItems(
        path,
        bucketId: null,
        clearRelated: clearRelated,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File deleted')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  Future<void> _handleDownload() async {
    final path = _file?['name'] as String?;
    if (path == null || path.isEmpty) return;
    try {
      final ps = ServiceLocator.persistenceService;
      final dyn = ps as dynamic;
      String? signed;
      try {
        final fn = dyn.getSignedUrl;
        if (fn != null && fn is Function) {
          signed = await dyn.getSignedUrl(path);
        }
      } catch (_) {}
      if (signed != null && signed.isNotEmpty) {
        if (!mounted) return;
        final uri = Uri.tryParse(signed);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opened download link in browser')),
          );
        } else {
          await Clipboard.setData(ClipboardData(text: signed));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download link copied (open in browser)'),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download link available')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get download link: $e')),
      );
    }
  }

  Future<void> _downloadToDevice() async {
    final path = _file?['name'] as String?;
    if (path == null || path.isEmpty) return;

    try {
      final ps = ServiceLocator.persistenceService;
      String? signed;
      try {
        final dyn = ps as dynamic;
        final fn = dyn.getSignedUrl;
        if (fn != null && fn is Function) signed = await dyn.getSignedUrl(path);
      } catch (_) {}

      if (signed == null || signed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No download link available')),
        );
        return;
      }

      final uri = Uri.parse(signed);
      // Show progress dialog
      var savedPath = '';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          double progress = 0.0;
          // Using StatefulBuilder to update progress
          return StatefulBuilder(
            builder: (context, setState) {
              // Begin download when dialog is shown by scheduling in microtask
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  // Special-case data: URIs in tests and small images - avoid HTTP when data URI
                  if (signed != null && signed.startsWith('data:')) {
                    // format: data:<mime>;base64,<payload>
                    final parts = signed.split(',');
                    if (parts.length == 2) {
                      final payload = parts[1];
                      final bytes = base64Decode(payload);
                      final tempDir =
                          await getDownloadsDirectory() ??
                          await getTemporaryDirectory();
                      final filename = uri.pathSegments.isNotEmpty
                          ? uri.pathSegments.last
                          : path.split('/').last;
                      final file = File('${tempDir.path}/$filename');
                      await file.writeAsBytes(bytes);
                      savedPath = file.path;
                      if (mounted) Navigator.of(dialogCtx).pop();
                      return;
                    }
                  }
                  final client = http.Client();
                  final req = http.Request('GET', uri);
                  final res = await client.send(req);
                  final total = res.contentLength ?? 0;
                  final tempDir =
                      await getDownloadsDirectory() ??
                      await getTemporaryDirectory();
                  final filename = uri.pathSegments.isNotEmpty
                      ? uri.pathSegments.last
                      : path.split('/').last;
                  final file = File('${tempDir.path}/$filename');
                  final sink = file.openWrite();
                  int received = 0;
                  await for (final chunk in res.stream) {
                    received += chunk.length;
                    sink.add(chunk);
                    if (total > 0) {
                      setState(() {
                        progress = received / total;
                      });
                    }
                  }
                  await sink.flush();
                  await sink.close();
                  savedPath = file.path;
                  client.close();
                  if (mounted) Navigator.of(dialogCtx).pop();
                } catch (e) {
                  if (mounted) Navigator.of(dialogCtx).pop();
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download failed: $e')),
                    );
                }
              });
              return AlertDialog(
                title: const Text('Downloading'),
                content: SizedBox(
                  height: 80,
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 12),
                      Text('${(progress * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted) return;
      if (savedPath.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved to $savedPath')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  void _showFullScreenPhoto(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: StorageImage(
                  imageUrl: url,
                  persistence: ServiceLocator.persistenceService,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/admin'),
                child: const Text('Admin'),
              ),
              const Text(' > '),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/admin/storage'),
                child: const Text('Storage'),
              ),
              const Text(' > '),
              const Text(
                'File Details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(child: _buildContent()),
      ],
    );

    if (!widget.wrapWithAdminLayout) return content;
    return AdminLayout(
      currentRoute: '/admin/storage/files',
      breadcrumbs: [
        BreadcrumbItem(
          label: 'Admin',
          onTap: () => Navigator.pushReplacementNamed(context, '/admin'),
        ),
        BreadcrumbItem(
          label: 'Storage',
          onTap: () =>
              Navigator.pushReplacementNamed(context, '/admin/storage'),
        ),
        const BreadcrumbItem(label: 'Files'),
        const BreadcrumbItem(label: 'Details'),
      ],
      child: content,
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_file == null) return _buildNotFound();
    final f = _file!;
    final createdRaw = f['created_at'];
    DateTime? createdAt;
    if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);
    if (createdRaw is DateTime) createdAt = createdRaw;
    final size = f['size_bytes'];
    final owner = f['owner'];
    final path = f['name'] as String? ?? '';
    final basename = path.split('/').last;
    final photoUrl = f['name'] as String?;
    final type = (path.contains('.') ? path.split('.').last : 'unknown');
    final related =
        (f['metadata'] is Map && (f['metadata'] as Map)['item_id'] != null)
        ? (f['metadata'] as Map)['item_id']
        : (f['item_id'] ?? f['related_item_id']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  basename,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _handleDownload,
                icon: const Icon(Icons.download),
              ),
              IconButton(
                onPressed: _downloadToDevice,
                icon: const Icon(Icons.save_alt),
                tooltip: 'Download to device',
              ),
              IconButton(
                onPressed: () => _showFullScreenPhoto(photoUrl ?? ''),
                icon: const Icon(Icons.fullscreen),
              ),
              IconButton(
                onPressed: _handleDelete,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Preview
          if (photoUrl != null && photoUrl.isNotEmpty)
            Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: StorageImage(
                    imageUrl: photoUrl,
                    persistence: ServiceLocator.persistenceService,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Metadata',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Path', path),
                  _buildInfoRow('Size', _fmtBytes(size)),
                  _buildInfoRow('Owner', owner?.toString() ?? '—'),
                  _buildInfoRow('Type', type),
                  _buildInfoRow('Related Item', related?.toString() ?? '—'),
                  _buildInfoRow(
                    'Created',
                    createdAt != null
                        ? DateFormat.yMMMd().add_jm().format(createdAt)
                        : '—',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFileDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('File not found'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/admin/storage/files'),
            child: const Text('Back to Files'),
          ),
        ],
      ),
    );
  }

  String _fmtBytes(dynamic v) {
    if (v == null) return '0 B';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (n < 1024) return '${n.toStringAsFixed(0)} B';
    final kb = n / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(2)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }
}
