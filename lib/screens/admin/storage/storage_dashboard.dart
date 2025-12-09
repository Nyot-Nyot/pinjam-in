import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pinjam_in/constants/storage_keys.dart';
// removed intl import - not used
import 'package:pinjam_in/screens/admin/admin_layout.dart';
import 'package:pinjam_in/services/storage_service.dart';
import 'package:pinjam_in/utils/logger.dart' as logger;
import 'package:pinjam_in/widgets/admin/breadcrumbs.dart';

class StorageDashboardScreen extends StatefulWidget {
  final StorageService? service;

  /// When false, the AdminLayout wrapper will not be used. Useful for tests.
  final bool wrapWithAdminLayout;

  const StorageDashboardScreen({
    super.key,
    this.service,
    this.wrapWithAdminLayout = true,
  });

  @override
  State<StorageDashboardScreen> createState() => _StorageDashboardScreenState();
}

class _StorageDashboardScreenState extends State<StorageDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String? _error;
  DateTime? _lastUpdated;
  List<Map<String, dynamic>> _storageByUser = [];
  List<Map<String, dynamic>> _fileTypeDistribution = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = widget.service ?? StorageService.instance;
      final res = await svc.getStorageStats(bucketId: StorageKeys.imagesBucket);
      final byUser = await svc.getStorageByUser(
        bucketId: StorageKeys.imagesBucket,
        limit: 10,
      );
      final fileTypes = await svc.getFileTypeDistribution(
        bucketId: StorageKeys.imagesBucket,
      );
      // ensure we ask for the configured bucket
      // we pass a bucket explicitly in case the RPC default differs
      // from environment setup (older function or other defaults)
      // Note: StorageKeys.imagesBucket is 'item_photos'.
      setState(() {
        _stats = res;
        _storageByUser = byUser;
        _fileTypeDistribution = fileTypes;
        _lastUpdated = DateTime.now();
      });
      // Stats loaded; keep a warning if both totals zero
      // If stats appear empty (0 on key metrics), log a warning to help debug
      final tf = _toInt(_stats['total_files']);
      final ts = _toInt(_stats['total_size_bytes']);
      if (tf == 0 && ts == 0) {
        logger.AppLogger.warning(
          'StorageDashboard: total_files and total_size_bytes are both zero. Check RPC response or permissions',
          'StorageDashboard',
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtBytes(dynamic value) {
    if (value == null) return '0 B';
    final bytes = (value as num).toDouble();
    if (bytes <= 1024) return '${bytes.toStringAsFixed(0)} B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(2)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _buildCard(String label, String value, IconData icon) {
    return ConstrainedBox(
      // Ensure each card has a reasonable minimum height so that
      // short grid tile heights don't cause an overflow inside the
      // Column. Also allow some max to keep things compact.
      constraints: const BoxConstraints(minHeight: 64, maxHeight: 120),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(radius: 16, child: Icon(icon, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final totalFiles = _toInt(_stats['total_files']);
    final totalSize = _toInt(_stats['total_size_bytes']);
    final orphaned = _toInt(_stats['orphaned_files']);
    final itemsWithPhotos = _toInt(_stats['items_with_photos']);

    // 'width' has been replaced by 'screenWidth' above; keep a reference if needed in future.
    // var isSmall = screenWidth < 480; // unused for now, may be used for future UI tweaks
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 480 ? 1 : 2;
    // The grid tiles should be tall enough to fit our metric cards.
    // Using mainAxisExtent (fixed tile height) gives more predictable
    // layout across different screen sizes and avoids tiny heights
    // that cause the content to overflow inside columns.
    final tileHeight = screenWidth < 480 ? 92.0 : 88.0;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        // Prefer fixed tile height when available so small screens
        // don't force the grid to use a very short height.
        mainAxisExtent: tileHeight,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _buildCard('Total files', '$totalFiles', Icons.insert_drive_file),
        _buildCard('Total size', _fmtBytes(totalSize), Icons.storage),
        _buildCard('Items with photos', '$itemsWithPhotos', Icons.photo),
        _buildCard('Orphaned files', '$orphaned', Icons.delete_forever),
      ],
    );
  }

  Widget _buildCharts() {
    // admin_get_storage_stats doesn't return trend or breakdown — show placeholders
    final totalSize = _toDouble(_stats['total_size_bytes']);
    final points = List.generate(
      7,
      (i) => FlSpot(
        i.toDouble(),
        (totalSize * (0.85 + (i / 100.0))).toDouble() / 1048576.0,
      ),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final chartHeight = screenWidth < 480 ? 120.0 : 180.0;

    return Column(
      children: [
        // Chart title and legend
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              // On narrow widths, stack title and legend
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Storage usage (MB)'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(width: 12, height: 8, color: Colors.cyan),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Total size (MB): ${_toDouble(totalSize).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                const Expanded(child: Text('Storage usage (MB)')),
                Flexible(
                  fit: FlexFit.loose,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 8, color: Colors.cyan),
                      const SizedBox(width: 6),
                      Text(
                        'Total size (MB): ${(_toDouble(totalSize) / 1048576.0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              height: chartHeight,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx > 6) {
                            return const SizedBox.shrink();
                          }
                          return Text('D-${6 - idx}');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()} MB');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(2)} MB',
                              const TextStyle(color: Colors.black),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: true),
                    ),
                  ],
                  minY: 0,
                  maxY:
                      (points.map((e) => e.y).reduce((a, b) => a > b ? a : b) *
                          1.2) +
                      1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Top users (top 10) by storage used
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top users by storage (top 10)'),
                const SizedBox(height: 8),
                _storageByUser.isEmpty
                    ? const Text('No data available')
                    : Column(
                        children: _storageByUser.map((u) {
                          final email = (u['user_email'] ?? 'Unknown')
                              .toString();
                          final size = _fmtBytes(u['total_size_bytes']);
                          return ListTile(
                            dense: true,
                            title: Text(email),
                            trailing: Text(size),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // File type distribution pie chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('File type distribution'),
                const SizedBox(height: 8),
                _fileTypeDistribution.isEmpty
                    ? const Text(
                        'No breakdown available from backend (placeholder)',
                      )
                    : SizedBox(
                        height: 140,
                        child: Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sections: _fileTypeDistribution.map((f) {
                                    final cnt =
                                        (f['file_count'] as num?)?.toDouble() ??
                                        0.0;
                                    final ext = (f['extension'] ?? 'unknown')
                                        .toString();
                                    return PieChartSectionData(
                                      radius: 36,
                                      value: cnt,
                                      title: ext,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _fileTypeDistribution.map((f) {
                                  final name = (f['extension'] ?? 'unknown')
                                      .toString();
                                  final cnt = f['file_count'].toString();
                                  final size = _fmtBytes(f['total_size_bytes']);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Text('$name: $cnt files, $size'),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('File type distribution (not available)'),
                SizedBox(height: 8),
                Text('No breakdown available from backend (placeholder)'),
              ],
            ),
          ),
        ),
        // Debug-only card (raw JSON) removed for production.
      ],
    );
  }

  Future<void> _handleCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run cleanup'),
        content: const Text(
          'Run storage cleanup (delete orphaned files). This action may be destructive. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Best effort: there's no RPC defined for this yet — show placeholder
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storage cleanup started (placeholder)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final breadcrumbs = [
      BreadcrumbItem(
        label: 'Admin',
        onTap: () {
          if (!mounted) return;
          navigator.pushReplacementNamed('/admin');
        },
      ),
      const BreadcrumbItem(label: 'Storage'),
    ];

    final List<Widget> contentWidgets;
    if (_isLoading) {
      contentWidgets = [const Center(child: CircularProgressIndicator())];
    } else if (_error != null) {
      contentWidgets = [Center(child: Text('Failed to load: $_error'))];
    } else {
      contentWidgets = [_buildStatsGrid(), _buildCharts()];
    }

    final content = ListView(
      padding: const EdgeInsets.all(12.0),
      children: [
        const Text(
          'Storage Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (_lastUpdated != null)
          Text(
            'Last updated: ${_lastUpdated.toString()}',
            style: const TextStyle(fontSize: 12),
          ),
        const SizedBox(height: 12),
        ...contentWidgets,
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _handleCleanup,
              icon: const Icon(Icons.auto_delete),
              label: const Text('Run cleanup'),
            ),
            OutlinedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            // spacing provided by Wrap
            OutlinedButton.icon(
              onPressed: () {
                if (!mounted) return;
                navigator.pushNamed('/admin/storage/files');
              },
              icon: const Icon(Icons.folder),
              label: const Text('View all files'),
            ),
          ],
        ),
      ],
    );

    if (!widget.wrapWithAdminLayout) return content;

    return AdminLayout(
      currentRoute: '/admin/storage',
      breadcrumbs: breadcrumbs,
      child: content,
    );
  }
}
