import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:url_launcher/url_launcher_string.dart';

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
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete file'),
        content: Text('Delete "$path" from storage? This cannot be undone.'),
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
    );
    if (confirmed != true) return;
    try {
      final ok = await _adminSvc.deleteStorageObject(path, bucketId: null);
      if (!ok)
        throw Exception('Delete reported success but file still present');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File deleted')));
      await _loadFiles();
    } catch (e) {
      developer.log('FileBrowser: error deleting $path -> $e');
      if (!mounted) return;
      final msg = e.toString();
      String userMsg;
      if (msg.contains('Deletion unsuccessful') ||
          msg.contains('object still present')) {
        userMsg =
            'Delete failed: object still present in storage; it may require server-side cleanup or retry.';
      } else {
        userMsg = 'Error deleting: $e';
      }
      // Show a detailed dialog with retry/copy action to help users retrieve details
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete failed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(userMsg),
                const SizedBox(height: 12),
                Text('Details: $msg', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: msg));
                Navigator.pop(c);
              },
              child: const Text('Copy details'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(c);
                // Retry the delete once more
                try {
                  developer.log('FileBrowser: retry delete $path');
                  final ok = await _adminSvc.deleteStorageObject(
                    path,
                    bucketId: null,
                  );
                  if (!ok)
                    throw Exception('Retry failed: object still present');
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('File deleted')));
                  await _loadFiles();
                } catch (e2) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Retry failed: $e2')));
                }
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleBulkDelete() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete selected files'),
        content: Text(
          'Delete ${_selected.length} files? This cannot be undone.',
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
    );
    if (confirmed != true) return;
    final toDelete = List<String>.from(_selected);
    try {
      for (final path in toDelete) {
        final ok = await _adminSvc.deleteStorageObject(path, bucketId: null);
        if (!ok) throw Exception('Some deletes failed');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Files deleted')));
      _selected.clear();
      await _loadFiles();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete failed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Bulk delete failed; some files may remain'),
                const SizedBox(height: 12),
                Text('Details: $msg', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: msg));
                Navigator.pop(c);
              },
              child: const Text('Copy details'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openDownloadLink(Map<String, dynamic> f) async {
    if (!mounted) return;
    final ctx = context;
    final ps = ServiceLocator.persistenceService;
    final name = (f['name'] ?? '').toString();

    // Show a small progress dialog while generating link
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      developer.log(
        'FileBrowser: _openDownloadLink called for ${name} with persistence=${ps.runtimeType}',
      );
      print(
        'FileBrowser: _openDownloadLink called for ${name} with persistence=${ps.runtimeType}',
      );
      // If 'name' is a direct URL (starts with http/https), use it directly
      if (name.startsWith('http://') || name.startsWith('https://')) {
        Navigator.pop(ctx);
        await launchUrlString(name, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Opened download link in browser')),
        );
        return;
      }

      String? signed;
      try {
        final dyn = ps as dynamic;
        if (dyn.getSignedUrl != null) {
          signed = await dyn.getSignedUrl(name) as String?;
        }
      } catch (_) {}
      developer.log(
        'FileBrowser: _openDownloadLink got signed=$signed for name=$name',
      );
      print('FileBrowser: _openDownloadLink got signed=$signed for name=$name');

      Navigator.pop(ctx);
      if (signed == null || signed.isEmpty) {
        // If persistence backend doesn't provide signed or public URL, show helpful message
        developer.log(
          'FileBrowser: No signed url for $name on ${ps.runtimeType}',
        );
        print('FileBrowser: No signed url for $name on ${ps.runtimeType}');
        if (ps is! SupabasePersistence) {
          Navigator.pop(ctx);
          if (!mounted) return;
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Persistence backend does not support downloads'),
            ),
          );
          return;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'No download link available: Supabase did not return a URL for this object. Check file path and bucket permissions.',
            ),
          ),
        );
        return;
      }

      // Open in external browser
      await launchUrlString(signed, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Opened download link in browser')),
      );
    } catch (e) {
      Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Failed to open link: $e')));
    }
  }

  Future<void> _downloadToDevice(Map<String, dynamic> f) async {
    if (!mounted) return;
    final ctx = context;
    final ps = ServiceLocator.persistenceService;
    final name = (f['name'] ?? '').toString();

    if (kIsWeb) {
      // Web cannot easily stream to device; open in browser as fallback
      await _openDownloadLink(f);
      return;
    }

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) {
        var progress = 0.0;
        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setState) {
            return AlertDialog(
              title: const Text('Downloading'),
              content: SizedBox(
                height: 80,
                child: Column(
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    String? signed;
    try {
      developer.log(
        'FileBrowser: _downloadToDevice called for $name with persistence=${ps.runtimeType}',
      );
      print(
        'FileBrowser: _downloadToDevice called for $name with persistence=${ps.runtimeType}',
      );
      final dyn = ps as dynamic;
      try {
        if (dyn.getSignedUrl != null)
          signed = await dyn.getSignedUrl(name) as String?;
      } catch (_) {}

      if ((signed == null || signed.isEmpty) && dyn.getPublicUrl != null) {
        try {
          signed = await dyn.getPublicUrl(name) as String?;
        } catch (_) {}
      }

      developer.log(
        'FileBrowser: _downloadToDevice resolved link=$signed for $name',
      );
      print('FileBrowser: _downloadToDevice resolved link=$signed for $name');
      if (signed == null || signed.isEmpty) {
        Navigator.pop(ctx);
        if (!mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('No download link available')),
        );
        return;
      }

      final client = http.Client();
      final req = http.Request('GET', Uri.parse(signed));
      final streamed = await client.send(req);
      final total = streamed.contentLength ?? 0;
      final tmpDir = await getTemporaryDirectory();
      final fileName = name.contains('/') ? name.split('/').last : name;
      final file = File('${tmpDir.path}/$fileName');
      final sink = file.openWrite();
      var received = 0;
      // Update progress via periodic callbacks to the active dialog
      final cancelToken = <bool>[false];
      // No-op: public URL handling moved earlier

      await for (final chunk in streamed.stream) {
        if (cancelToken[0]) break;
        sink.add(chunk);
        received += chunk.length;
        // final newProgress = total > 0 ? received / total : null;
        // Update the active progress dialog
        if (mounted) {
          // find the active dialog's state and set progress: using navigator and simple rebuild is complex
          // For now, update via a SnackBar for progress (periodically)
          if (total > 0) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  'Downloading... ${((received / total) * 100).toStringAsFixed(0)}%',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(
              ctx,
            ).showSnackBar(const SnackBar(content: Text('Downloading...')));
          }
        }
      }
      await sink.flush();
      await sink.close();
      client.close();

      Navigator.pop(ctx); // close progress dialog
      if (!mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Downloaded to ${file.path}')));
    } catch (e) {
      Navigator.pop(ctx);
      if (!mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 56,
                            height: 56,
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
                        // Show download icon only when supported by persistence backend
                        // (we detect dynamic getSignedUrl/getPublicUrl method) or when name is an http(s) URL
                        if (() {
                          final psDyn =
                              ServiceLocator.persistenceService as dynamic;
                          try {
                            final supportsSigned = psDyn.getSignedUrl != null;
                            if (supportsSigned) return true;
                          } catch (_) {}
                          return path.startsWith('http://') ||
                              path.startsWith('https://');
                        }())
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Download',
                            onPressed: () async {
                              // Show options: Open in browser or download to device
                              await showModalBottomSheet<void>(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.open_in_new),
                                        title: const Text('Open in Browser'),
                                        onTap: () async {
                                          Navigator.of(ctx).pop();
                                          await _openDownloadLink(f);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.save_alt),
                                        title: const Text('Download to Device'),
                                        onTap: () async {
                                          Navigator.of(ctx).pop();
                                          await _downloadToDevice(f);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
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
