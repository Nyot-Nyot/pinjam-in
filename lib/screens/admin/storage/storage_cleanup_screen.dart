import 'package:flutter/material.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/storage_service.dart';
import 'package:pinjam_in/widgets/storage_image.dart';

class StorageCleanupScreen extends StatefulWidget {
  final StorageService? storageService;
  final AdminService? adminService;

  const StorageCleanupScreen({Key? key, this.storageService, this.adminService})
    : super(key: key);

  @override
  State<StorageCleanupScreen> createState() => _StorageCleanupScreenState();
}

class _StorageCleanupScreenState extends State<StorageCleanupScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _files = [];
  final Set<String> _selected = {};
  late final StorageService _svc;
  late final AdminService _admin;

  @override
  void initState() {
    super.initState();
    _svc = widget.storageService ?? StorageService.instance;
    _admin = widget.adminService ?? AdminService.instance;
    _loadOrphaned();
  }

  Future<void> _loadOrphaned() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _svc.listOrphanedFiles(limit: 200);
      setState(() {
        _files = res;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orphaned files: $e')),
      );
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

  Future<void> _handleDeleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete orphaned files'),
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

    setState(() {
      _isLoading = true;
    });
    try {
      final toDelete = List<String>.from(_selected);
      // Use AdminService.bulk delete method we just added
      final res = await _admin.deleteStorageObjects(toDelete);
      final deleted = (res['deleted'] as List).length;
      final failed = (res['failed'] as List).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deleted files, failed $failed')),
      );
      _selected.clear();
      await _loadOrphaned();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = _files.fold<int>(
      0,
      (prev, e) => prev + (e['size_bytes'] as int? ?? 0),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Storage Cleanup')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                // Use a Wrap inside an Expanded to allow the buttons to wrap
                // to a new line when space is constrained instead of causing
                // a RenderFlex overflow.
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loadOrphaned,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _selected.isEmpty || _isLoading
                            ? null
                            : _handleDeleteSelected,
                        icon: const Icon(Icons.delete_forever),
                        label: Text('Delete (${_selected.length})'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Allow the stats text to shrink on narrow devices instead of
                // overflowing the row. Use Flexible to allow the text to take
                // up remaining space and shrink with ellipsis.
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    '${_files.length} orphaned files • ${_fmtBytes(totalBytes)}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (!_isLoading && _files.isEmpty)
              const Expanded(child: Center(child: Text('No orphaned files'))),
            if (!_isLoading && _files.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _files.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    final name = (f['name'] ?? '').toString();
                    final size = f['size_bytes'] as int? ?? 0;
                    return ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 36,
                            child: Checkbox(
                              value: _selected.contains(name),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true)
                                    _selected.add(name);
                                  else
                                    _selected.remove(name);
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
                                imageUrl: name,
                                persistence: ServiceLocator.persistenceService,
                                width: 56,
                                height: 56,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(name.split('/').last),
                      subtitle: Text(_fmtBytes(size)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () async {
                          final ok = await showDialog<bool?>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete file'),
                              content: Text(
                                'Delete "$name"? This cannot be undone.',
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
                          if (ok != true) return;
                          setState(() => _isLoading = true);
                          try {
                            final result = await _admin.deleteStorageObjects([
                              name,
                            ]);
                            final deleted = (result['deleted'] as List).length;
                            final failed = (result['failed'] as List).length;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Deleted $deleted file(s), failed $failed',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                            await _loadOrphaned();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
