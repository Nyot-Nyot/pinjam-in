import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/screens/admin/admin_layout.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/storage_service.dart';
import 'package:pinjam_in/services/supabase_persistence.dart';
import 'package:pinjam_in/widgets/admin/breadcrumbs.dart';
import 'package:pinjam_in/widgets/storage_image.dart';

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

  late final StorageService _svc;
  late final AdminService _adminSvc;

  @override
  void initState() {
    super.initState();
    _svc = widget.storageService ?? StorageService.instance;
    _adminSvc = widget.adminService ?? AdminService.instance;
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
      setState(() {
        _files = res;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      await _adminSvc.deleteStorageObject(path, bucketId: null);
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
          Row(
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
              const Spacer(),
              IconButton(
                onPressed: _loadFiles,
                icon: const Icon(Icons.refresh),
              ),
            ],
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
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: StorageImage(
                          imageUrl: f['name'] as String?,
                          persistence: ServiceLocator.persistenceService,
                          width: 56,
                          height: 56,
                        ),
                      ),
                    ),
                    title: Text(f['name'] ?? ''),
                    subtitle: Text(
                      '${_fmtBytes(f['size_bytes'])} • ${createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : ''}',
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
                                if (signed != null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Download link copied (open in browser)',
                                      ),
                                    ),
                                  );
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
