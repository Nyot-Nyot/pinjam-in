import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/admin_service.dart';
import '../../../services/audit_service.dart';
import '../../../widgets/admin/breadcrumbs.dart';
import '../admin_layout.dart';

/// Audit Logs admin screen, minimal and test-friendly.
class AuditLogsScreen extends StatefulWidget {
  final bool wrapWithAdminLayout;
  final AuditService? auditServiceOverride;
  final AdminService? adminServiceOverride;
  final void Function(Map<String, dynamic> row)? onRecordTap;

  const AuditLogsScreen({
    Key? key,
    this.wrapWithAdminLayout = true,
    this.auditServiceOverride,
    this.adminServiceOverride,
    this.onRecordTap,
  }) : super(key: key);

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  // Services
  late final AuditService _auditService;
  late final AdminService _adminService;

  // State
  final List<Map<String, dynamic>> _logs = [];
  final List<Map<String, dynamic>> _adminUsers = [];
  bool _isLoading = false;
  String? _error;
  String? _filterAction;
  String? _filterTable;
  String? _filterUserId;
  final TextEditingController _recordIdController = TextEditingController();
  DateTimeRange? _selectedRange;
  int _limit = 50; // per spec
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _auditService = widget.auditServiceOverride ?? auditService;
    _adminService = widget.adminServiceOverride ?? AdminService.instance;
    _loadAdmins();
    _loadLogs();
  }

  @override
  void dispose() {
    _recordIdController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _auditService.getAuditLogs(
        limit: _limit,
        offset: _offset,
        actionType: _filterAction,
        tableName: _filterTable,
        adminUserId: _filterUserId,
        recordId: _recordIdController.text.isEmpty
            ? null
            : _recordIdController.text,
        dateFrom: _selectedRange?.start,
        dateTo: _selectedRange?.end,
      );
      setState(() {
        _logs
          ..clear()
          ..addAll(list);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadAdmins() async {
    try {
      final list = await _adminService.getAllUsers(limit: 200, role: 'admin');
      setState(() {
        _adminUsers.clear();
        _adminUsers.addAll(list);
      });
    } catch (e) {
      // ignore - admins are optional, we still allow manual input
    }
  }

  String _summaryForRow(Map<String, dynamic> row) {
    try {
      final newValues = row['new_values'];
      final oldValues = row['old_values'];
      if (newValues is Map && oldValues is Map) {
        for (final k in newValues.keys) {
          final newVal = newValues[k]?.toString() ?? '';
          final oldVal = oldValues[k]?.toString() ?? '';
          if (newVal != oldVal) {
            return 'Updated $k from "$oldVal" to "$newVal"';
          }
        }
      }
      if (newValues is Map && newValues.isNotEmpty) {
        return 'Changed ${newValues.keys.join(', ')}';
      }
      if (oldValues is Map && oldValues.isNotEmpty) {
        return 'Removed ${oldValues.keys.join(', ')}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  void _onRecordTap(Map<String, dynamic> row) {
    if (widget.onRecordTap != null) return widget.onRecordTap!(row);
    final table = (row['table_name'] ?? '').toString();
    final id = row['record_id']?.toString();
    if (id == null || id.isEmpty) return;
    if (table == 'profiles') {
      Navigator.pushNamed(context, '/admin/users/$id');
    } else if (table == 'items') {
      Navigator.pushNamed(context, '/admin/items/$id');
    }
  }

  void _openDetails(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Action: ${row['action_type'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Created at: ${row['created_at'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Table: ${row['table_name'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Record: ${row['record_id'] ?? ''}'),
              const SizedBox(height: 8),
              const Text('Old vs New values:'),
              const SizedBox(height: 8),
              _buildDiffView(row['old_values'] ?? {}, row['new_values'] ?? {}),
              const SizedBox(height: 8),
              const Text('New values:'),
              Text(jsonEncode(row['new_values'] ?? {})),
              const SizedBox(height: 8),
              const Text('Metadata:'),
              Text(jsonEncode(row['metadata'] ?? {})),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffView(Map oldValues, Map newValues) {
    final keys = <String>{}..addAll(oldValues.keys.cast<String>());
    keys.addAll(newValues.keys.cast<String>());
    final items = keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((k) {
        final oldV = oldValues[k]?.toString() ?? '';
        final newV = newValues[k]?.toString() ?? '';
        final changed = oldV != newV;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  k,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  oldV,
                  style: TextStyle(color: changed ? Colors.red : Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_right_alt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  newV,
                  style: TextStyle(
                    color: changed ? Colors.green : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _exportCsv() async {
    final rows = await _auditService.getAuditLogs(
      limit: 1000,
      offset: 0,
      actionType: _filterAction,
      tableName: _filterTable,
      adminUserId: _filterUserId,
      recordId: _recordIdController.text.isEmpty
          ? null
          : _recordIdController.text,
      dateFrom: _selectedRange?.start,
      dateTo: _selectedRange?.end,
    );

    final out = StringBuffer();
    out.writeln(
      'id,action_type,table_name,record_id,admin_user_full_name,created_at,summary,old_values,new_values',
    );
    for (final r in rows) {
      final id = (r['id'] ?? '').toString().replaceAll(',', '');
      final action = (r['action_type'] ?? '').toString().replaceAll(',', '');
      final table = (r['table_name'] ?? '').toString().replaceAll(',', '');
      final record = (r['record_id'] ?? '').toString().replaceAll(',', '');
      final admin = (r['admin_user_full_name'] ?? '').toString().replaceAll(
        ',',
        '',
      );
      final created = (r['created_at'] ?? '').toString().replaceAll(',', '');
      final summary = _summaryForRow(r).replaceAll(',', '');
      final oldv = jsonEncode(r['old_values'] ?? {}).replaceAll(',', ';');
      final newv = jsonEncode(r['new_values'] ?? {}).replaceAll(',', ';');
      out.writeln(
        '$id,$action,$table,$record,$admin,$created,$summary,$oldv,$newv',
      );
    }

    final csvStr = out.toString();
    // Show a dialog with CSV and copy button
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Export'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(child: SelectableText(csvStr)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csvStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied CSV to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _actionBadge(String? action) {
    final a = (action ?? '').toUpperCase();
    Color color;
    switch (a) {
      case 'CREATE':
        color = Colors.green;
        break;
      case 'UPDATE':
        color = Colors.blue;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      backgroundColor: color.withOpacity(0.12),
      label: Text(
        a,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                if (isNarrow) {
                  return Column(
                    children: [
                      DropdownButtonFormField<String?>(
                        key: const Key('audit-action-dropdown'),
                        value: _filterAction,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Action'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(
                            value: 'CREATE',
                            child: Text('CREATE'),
                          ),
                          DropdownMenuItem(
                            value: 'UPDATE',
                            child: Text('UPDATE'),
                          ),
                          DropdownMenuItem(
                            value: 'DELETE',
                            child: Text('DELETE'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterAction = v),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const Key('audit-date-range-button'),
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _selectedRange == null
                              ? 'Select date range'
                              : '${_selectedRange!.start.toLocal().toIso8601String().substring(0, 10)} — ${_selectedRange!.end.toLocal().toIso8601String().substring(0, 10)}',
                        ),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDateRange: _selectedRange,
                          );
                          if (range != null)
                            setState(() => _selectedRange = range);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        key: const Key('audit-table-dropdown'),
                        value: _filterTable,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Table'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(
                            value: 'items',
                            child: Text('Items'),
                          ),
                          DropdownMenuItem(
                            value: 'profiles',
                            child: Text('Users'),
                          ),
                          DropdownMenuItem(
                            value: 'audit_logs',
                            child: Text('Audit Logs'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterTable = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        key: const Key('audit-admin-dropdown'),
                        value: _filterUserId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Admin'),
                        items: _adminUsers
                            .map(
                              (u) => DropdownMenuItem(
                                value: (u['id'] ?? '').toString(),
                                child: Text(
                                  u['full_name'] ?? u['email'] ?? u['id'],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _filterUserId = v),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const Key('audit-action-dropdown'),
                        value: _filterAction,
                        decoration: const InputDecoration(labelText: 'Action'),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(
                            value: 'CREATE',
                            child: Text('CREATE'),
                          ),
                          DropdownMenuItem(
                            value: 'UPDATE',
                            child: Text('UPDATE'),
                          ),
                          DropdownMenuItem(
                            value: 'DELETE',
                            child: Text('DELETE'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterAction = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('audit-date-range-button'),
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _selectedRange == null
                              ? 'Select date range'
                              : '${_selectedRange!.start.toLocal().toIso8601String().substring(0, 10)} — ${_selectedRange!.end.toLocal().toIso8601String().substring(0, 10)}',
                        ),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDateRange: _selectedRange,
                          );
                          if (range != null)
                            setState(() => _selectedRange = range);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const Key('audit-table-dropdown'),
                        value: _filterTable,
                        decoration: const InputDecoration(labelText: 'Table'),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(
                            value: 'items',
                            child: Text('Items'),
                          ),
                          DropdownMenuItem(
                            value: 'profiles',
                            child: Text('Users'),
                          ),
                          DropdownMenuItem(
                            value: 'audit_logs',
                            child: Text('Audit Logs'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterTable = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: const Key('audit-admin-dropdown'),
                        value: _filterUserId,
                        decoration: const InputDecoration(labelText: 'Admin'),
                        isExpanded: true,
                        items: _adminUsers
                            .map(
                              (u) => DropdownMenuItem(
                                value: (u['id'] ?? '').toString(),
                                child: Text(
                                  u['full_name'] ?? u['email'] ?? u['id'],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _filterUserId = v),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            // Inline quick-action buttons (helps automated tests target the action)
            Wrap(
              key: const Key('audit-action-inline'),
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const Key('audit-action-all-button'),
                  onPressed: () => setState(() => _filterAction = null),
                  child: const Text('All'),
                ),
                TextButton(
                  key: const Key('audit-action-create-button'),
                  onPressed: () => setState(() => _filterAction = 'CREATE'),
                  child: const Text('CREATE'),
                ),
                TextButton(
                  key: const Key('audit-action-update-button'),
                  onPressed: () => setState(() => _filterAction = 'UPDATE'),
                  child: const Text('UPDATE'),
                ),
                TextButton(
                  key: const Key('audit-action-delete-button'),
                  onPressed: () => setState(() => _filterAction = 'DELETE'),
                  child: const Text('DELETE'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 480;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('audit-record-input'),
                        controller: _recordIdController,
                        decoration: const InputDecoration(
                          labelText: 'Record ID',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const Key('audit-refresh-button'),
                              onPressed: _loadLogs,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const Key('audit-export-button'),
                              icon: const Icon(Icons.download),
                              label: const Text('Export CSV'),
                              onPressed: _exportCsv,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('audit-record-input'),
                        controller: _recordIdController,
                        decoration: const InputDecoration(
                          labelText: 'Record ID',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('audit-refresh-button'),
                      onPressed: _loadLogs,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('audit-export-button'),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'),
                      onPressed: _exportCsv,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    if (_logs.isEmpty) return const Center(child: Text('No audit logs found'));

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            key: const Key('audit-list'),
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final row = _logs[index];
              return ListTile(
                leading: _actionBadge(row['action_type']),
                title: Text(row['admin_user_full_name'] ?? 'Unknown'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(row['created_at'] ?? '').toString().split('T').first} • ${row['table_name'] ?? ''}',
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () => _onRecordTap(row),
                            child: Text(
                              row['record_id']?.toString() ?? '',
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.blue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 4,
                          child: Text(
                            _summaryForRow(row),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () => _openDetails(row),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _offset == 0
                      ? null
                      : () {
                          setState(
                            () => _offset = (_offset - _limit).clamp(0, 999999),
                          );
                          _loadLogs();
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() => _offset = _offset + _limit);
                    _loadLogs();
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Showing ${_logs.length} rows, offset $_offset',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
    final content = AdminLayout(
      currentRoute: '/admin/audit',
      breadcrumbs: const [
        BreadcrumbItem(label: 'Admin'),
        BreadcrumbItem(label: 'Audit Logs'),
      ],
      child: inner,
    );
    return widget.wrapWithAdminLayout ? content : Scaffold(body: inner);
  }
}
