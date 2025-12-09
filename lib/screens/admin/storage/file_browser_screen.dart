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
import 'package:pinjam_in/services/supabase_persistence.dart';
import 'package:pinjam_in/widgets/admin/breadcrumbs.dart';
import 'package:pinjam_in/widgets/storage_image.dart';
import 'package:url_launcher/url_launcher.dart';

class FileBrowserScreen extends StatefulWidget {
  final bool wrapWithAdminLayout;
  final StorageService? storageService;
  final AdminService? adminService;
  const FileBrowserScreen({
    super.key,
    this.wrapWithAdminLayout = true,
    this.storageService,
    this.adminService,
  });

  @override
  FileBrowserScreenState createState() => FileBrowserScreenState();
}

class FileBrowserScreenState extends State<FileBrowserScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _files = [];
  String? _error;
  final int _limit = 25;
  int _offset = 0;
  String? _search;
  String? _filterOwner;
  bool _filterOrphanedOnly = false;
  List<Map<String, dynamic>> _users = [];
  final Set<String> _selected = {};
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  late final StorageService _svc;
  late final AdminService _adminSvc;

  @override
  void initState() {
    super.initState();
    _svc = widget.storageService ?? StorageService.instance;
    _adminSvc = widget.adminService ?? AdminService.instance;
    _loadUsers();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _svc.listFiles(
        bucketId: null,
        limit: _limit,
        offset: _offset,
        search: _search,
      );
      // Apply client-side filters for owner and orphaned-only since the RPC
      // does not yet expose those filters.
      var filtered = res;
      if (_filterOwner != null && _filterOwner!.isNotEmpty) {
        filtered = filtered
            .where((e) => (e['owner']?.toString() ?? '') == _filterOwner)
            .toList();
      }
      if (_filterOrphanedOnly) {
        filtered = filtered.where((e) => e['owner'] == null).toList();
      }
      if (_filterDateFrom != null || _filterDateTo != null) {
        filtered = filtered.where((e) {
          final createdRaw = e['created_at'];
          DateTime? createdAt;
          if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);
          if (createdRaw is DateTime) createdAt = createdRaw;
          if (createdAt == null) return false;
          if (_filterDateFrom != null && createdAt.isBefore(_filterDateFrom!))
            return false;
          if (_filterDateTo != null && createdAt.isAfter(_filterDateTo!))
            return false;
          return true;
        }).toList();
      }
      setState(() {
        _files = filtered;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _svc.getStorageByUser(limit: 200);
      setState(() {
        _users = users;
      });
    } catch (_) {
      // ignore
    }
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

  Future<void> _handleDelete(Map<String, dynamic> f) async {
    final path = f['name'] as String?;
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
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  Future<void> _downloadToDeviceForPath(String path) async {
    if (path.isEmpty) return;
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
      var savedPath = '';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          double progress = 0.0;
          return StatefulBuilder(
            builder: (context, setState) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  if (signed != null && signed.startsWith('data:')) {
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

  Future<void> _handleBulkDelete() async {
    if (_selected.isEmpty) return;
    bool clearRelated = true;
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Delete selected files'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Delete ${_selected.length} files? This cannot be undone.'),
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
    final toDelete = List<String>.from(_selected);
    try {
      for (final path in toDelete) {
        await _adminSvc.deleteStorageObjectAndClearItems(
          path,
          bucketId: null,
          clearRelated: clearRelated,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Files deleted')));
      _selected.clear();
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'File Browser',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by file name',
                    ),
                    onSubmitted: (v) {
                      _search = v.isEmpty ? null : v;
                      _offset = 0;
                      _loadFiles();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadFiles,
                  child: const Text('Search'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _search = null;
                    _offset = 0;
                    _loadFiles();
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: DropdownButton<String?>(
                    value: _filterOwner,
                    isExpanded: true,
                    hint: const Text('Filter by user'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All users'),
                      ),
                      ..._users.map(
                        (u) => DropdownMenuItem<String?>(
                          value: u['user_id']?.toString(),
                          child: SizedBox(
                            width: 150,
                            child: Text(
                              u['user_email']?.toString() ??
                                  u['user_id']?.toString() ??
                                  'Unknown',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterOwner = v);
                      _offset = 0;
                      _loadFiles();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _filterOrphanedOnly,
                      onChanged: (v) {
                        setState(() => _filterOrphanedOnly = v ?? false);
                        _offset = 0;
                        _loadFiles();
                      },
                    ),
                    const Text('Orphaned only'),
                  ],
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterDateFrom ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (d != null) {
                          setState(() => _filterDateFrom = d);
                          _offset = 0;
                          _loadFiles();
                        }
                      },
                      child: Text(
                        _filterDateFrom != null
                            ? DateFormat.yMd().format(_filterDateFrom!)
                            : 'From',
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterDateTo ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (d != null) {
                          setState(() => _filterDateTo = d);
                          _offset = 0;
                          _loadFiles();
                        }
                      },
                      child: Text(
                        _filterDateTo != null
                            ? DateFormat.yMd().format(_filterDateTo!)
                            : 'To',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadFiles,
                  icon: const Icon(Icons.refresh),
                ),
              ],
              spacing: 8,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (!_isLoading && _files.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('No files'),
            ),
          if (_files.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _files.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final f = _files[i];
                  final created = f['created_at'];
                  DateTime? createdAt;
                  if (created is String) createdAt = DateTime.tryParse(created);
                  if (created is DateTime) createdAt = created;
                  final path = f['name'] as String? ?? '';
                  return ListTile(
                    isThreeLine: true,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    minLeadingWidth: 88,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Checkbox(
                            value: _selected.contains(path),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(path);
                                } else {
                                  _selected.remove(path);
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: StorageImage(
                              imageUrl: path,
                              persistence: ServiceLocator.persistenceService,
                              width: 56,
                              height: 56,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Show only the basename to avoid horizontal overflow and
                    // keep the list readable. Provide a tooltip with full path.
                    title: Tooltip(
                      message: (f['name'] ?? '').toString(),
                      child: Text(
                        (f['name'] ?? '').toString().split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    subtitle: Text(
                      '${_fmtBytes(f['size_bytes'])} • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : ''}${f['owner'] != null ? ' • Owner: ${f['owner']}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          tooltip: 'Preview',
                          onPressed: () async {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(f['name'] ?? ''),
                                content: SizedBox(
                                  width: 400,
                                  height: 300,
                                  child: StorageImage(
                                    imageUrl: f['name'] as String?,
                                    persistence:
                                        ServiceLocator.persistenceService,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'Details',
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/admin/storage/files/detail',
                              arguments: f['name'] as String?,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Download',
                          onPressed: () async {
                            // Attempt to obtain a signed URL and open in external browser
                            final ctx = context;
                            try {
                              final ps = ServiceLocator.persistenceService;
                              if (ps is SupabasePersistence) {
                                final signed = await ps.getSignedUrl(
                                  f['name'] as String,
                                );
                                if (!mounted) return;
                                if (signed != null && signed.isNotEmpty) {
                                  final uri = Uri.tryParse(signed);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Opened download link in browser',
                                        ),
                                      ),
                                    );
                                  } else {
                                    await Clipboard.setData(
                                      ClipboardData(text: signed),
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Download link copied (open in browser)',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No download link available',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Persistence backend does not support downloads',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to get download link'),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.save_alt),
                          tooltip: 'Download to device',
                          onPressed: () async {
                            final p = f['name'] as String? ?? '';
                            await _downloadToDeviceForPath(p);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever),
                          tooltip: 'Delete',
                          onPressed: () => _handleDelete(f),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _selected.isEmpty ? null : _handleBulkDelete,
                    icon: const Icon(Icons.delete_forever),
                    label: Text('Delete (${_selected.length})'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      // Select all toggler
                      final all = _files
                          .map((e) => (e['name'] ?? '').toString())
                          .where((s) => s.isNotEmpty)
                          .toList();
                      setState(() {
                        if (_selected.length == all.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(all);
                        }
                      });
                    },
                    child: const Text('Toggle Select All'),
                  ),
                ],
                mainAxisSize: MainAxisSize.min,
              ),
            ),
          if (_files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _offset - _limit >= 0
                        ? () {
                            setState(() => _offset = _offset - _limit);
                            _loadFiles();
                          }
                        : null,
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _files.length == _limit
                        ? () {
                            setState(() => _offset = _offset + _limit);
                            _loadFiles();
                          }
                        : null,
                    child: const Text('Next'),
                  ),
                  const Spacer(),
                  Text('Offset: $_offset'),
                ],
              ),
            ),
        ],
      ),
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
      ],
      child: content,
    );
  }
}
