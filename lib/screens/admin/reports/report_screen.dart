import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/report_service.dart';
import '../../admin/admin_layout.dart';

/// Simple Reports UI for Admin panel.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.wrapWithAdminLayout = true});
  final bool wrapWithAdminLayout;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum ReportType { userSummary, itemsSummary, overdueItems }

class _ReportScreenState extends State<ReportScreen> {
  ReportType _selected = ReportType.userSummary;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.subtract(const Duration(days: 30)),
      firstDate: first,
      lastDate: now,
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: first,
      lastDate: now,
    );
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _preview() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
    });
    final reportService = ReportService.instance;
    try {
      List<Map<String, dynamic>> rows;
      if (_selected == ReportType.userSummary) {
        rows = await reportService.getUserSummary(
          start: _startDate,
          end: _endDate,
          limit: 50,
        );
      } else if (_selected == ReportType.itemsSummary) {
        rows = await reportService.getItemsSummary();
      } else {
        rows = await reportService.getOverdueItems(
          start: _startDate,
          end: _endDate,
          limit: 50,
        );
      }
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }
    final csv = ReportService.instance.exportToCsv(_rows);
    // Copy to clipboard as a simple cross-platform fallback for export.
    await Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard.')));
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Reports';
    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<ReportType>(
                        value: _selected,
                        items: const [
                          DropdownMenuItem(
                            value: ReportType.userSummary,
                            child: Text('User Summary'),
                          ),
                          DropdownMenuItem(
                            value: ReportType.itemsSummary,
                            child: Text('Items Summary'),
                          ),
                          DropdownMenuItem(
                            value: ReportType.overdueItems,
                            child: Text('Overdue Items'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selected = v!),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickStart,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _startDate == null
                              ? 'Start date'
                              : _startDate!.toIso8601String().substring(0, 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _pickEnd,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _endDate == null
                              ? 'End date'
                              : _endDate!.toIso8601String().substring(0, 10),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _loading ? null : _preview,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Preview'),
                      ),
                      ElevatedButton(
                        onPressed: _rows.isEmpty ? null : _exportCsv,
                        child: const Text('Export CSV'),
                      ),
                      Tooltip(
                        message: 'Export PDF (placeholder)',
                        child: ElevatedButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Export PDF'),
                              content: const Text(
                                'PDF export not implemented yet.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('Export PDF'),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error ?? '',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildPreviewTable(),
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.wrapWithAdminLayout) return content;

    return AdminLayout(
      currentRoute: '/admin/reports',
      breadcrumbs: const [],
      child: content,
    );
  }

  Widget _buildPreviewTable() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No preview data. Click Preview to load report.'),
      );
    }
    // Build columns from keys of first row
    final headers = _rows.first.keys.toList();
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: DataTable(
        columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
        rows: _rows
            .map(
              (r) => DataRow(
                cells: headers
                    .map((h) => DataCell(Text(r[h]?.toString() ?? '')))
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}
