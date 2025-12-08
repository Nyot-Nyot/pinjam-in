import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/admin/breadcrumbs.dart';
import '../admin_layout.dart';

/// ItemsListScreen - Admin screen to view and manage all items
///
/// Features:
/// - Data table with item information (photo, name, owner, status, dates)
/// - Search by item name, borrower name, notes
/// - Filter by status, owner, date range
/// - Pagination (20 items per page)
/// - Bulk actions (status update, delete)
/// - Highlight overdue items
class ItemsListScreen extends StatefulWidget {
  const ItemsListScreen({super.key});

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  int _pageSize = 20;
  int _currentPage = 0;
  int _totalItems = 0;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String? _ownerFilter;
  Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final offset = _currentPage * _pageSize;

      print('[ItemsList] Calling admin_get_all_items RPC...');
      print(
        '[ItemsList] Params: limit=$_pageSize, offset=$offset, search=$_searchQuery, status=$_statusFilter, owner=$_ownerFilter',
      );

      // Call admin function to get items
      final response = await _supabase.rpc(
        'admin_get_all_items',
        params: {
          'p_limit': _pageSize,
          'p_offset': offset,
          'p_search': _searchQuery.isEmpty ? null : _searchQuery,
          'p_status_filter': _statusFilter == 'all' ? null : _statusFilter,
          'p_user_filter':
              _ownerFilter, // Note: Backend expects p_user_filter, not p_owner_filter
        },
      );

      print('[ItemsList] RPC response type: ${response.runtimeType}');
      print('[ItemsList] RPC response: $response');

      final List<dynamic> itemsList = response as List;

      print('[ItemsList] Fetched ${itemsList.length} items');

      setState(() {
        _items = itemsList.cast<Map<String, dynamic>>();
        // Estimate total items (backend doesn't return total count)
        _totalItems = _items.isNotEmpty
            ? (_currentPage + 2) * _pageSize
            : _currentPage * _pageSize;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('[ItemsList] Error loading items: $e');
      print('[ItemsList] Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to load items: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshItems() async {
    _selectedItemIds.clear();
    await _loadItems();
  }

  void _onSearchSubmitted(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
    });
    _loadItems();
  }

  void _onFilterChanged() {
    setState(() {
      _currentPage = 0;
    });
    _loadItems();
  }

  void _onPageChanged(int newPage) {
    setState(() {
      _currentPage = newPage;
      _selectedItemIds.clear();
    });
    _loadItems();
  }

  void _onSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedItemIds.addAll(_items.map((item) => item['id'] as String));
      } else {
        _selectedItemIds.clear();
      }
    });
  }

  void _onItemSelected(String itemId, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedItemIds.add(itemId);
      } else {
        _selectedItemIds.remove(itemId);
      }
    });
  }

  Future<void> _handleBulkStatusUpdate() async {
    if (_selectedItemIds.isEmpty) return;

    // Show status selection dialog
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update status for ${_selectedItemIds.length} selected items?',
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Mark as Returned'),
              leading: Radio<String>(
                value: 'returned',
                groupValue: null,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              onTap: () => Navigator.pop(context, 'returned'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newStatus == null || !mounted) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Updating items...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Update each item
      for (final itemId in _selectedItemIds) {
        await _supabase.rpc(
          'admin_update_item_status',
          params: {'p_item_id': itemId, 'p_new_status': newStatus},
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedItemIds.length} items updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedItemIds.clear());
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedItemIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Items'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedItemIds.length} items?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting items...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Delete each item
      for (final itemId in _selectedItemIds) {
        await _supabase.rpc('admin_delete_item', params: {'p_item_id': itemId});
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedItemIds.length} items deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedItemIds.clear());
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleViewItem(String itemId) {
    Navigator.pushNamed(context, '/admin/items/$itemId');
  }

  void _handleEditItem(String itemId) {
    Navigator.pushNamed(context, '/admin/items/$itemId/edit');
  }

  Future<void> _handleDeleteItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Item'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this item?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _supabase.rpc('admin_delete_item', params: {'p_item_id': itemId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleDeleteItem(itemId),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/items',
      breadcrumbs: [
        BreadcrumbItem(
          label: 'Admin',
          onTap: () => Navigator.pushNamed(context, '/admin'),
        ),
        const BreadcrumbItem(label: 'Items'),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Items Management',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/admin/items/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create'),
                      ),
                      if (_selectedItemIds.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            '${_selectedItemIds.length} selected',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _selectedItemIds.clear()),
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _handleBulkStatusUpdate,
                          icon: const Icon(Icons.edit),
                          label: const Text('Update Status'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _handleBulkDelete,
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                // Search
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Search by name, borrower, notes...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _onSearchSubmitted,
                  ),
                ),

                // Status Filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(
                        value: 'borrowed',
                        child: Text('Borrowed'),
                      ),
                      DropdownMenuItem(
                        value: 'returned',
                        child: Text('Returned'),
                      ),
                      DropdownMenuItem(
                        value: 'overdue',
                        child: Text('Overdue'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _statusFilter = value);
                        _onFilterChanged();
                      }
                    },
                  ),
                ),

                // Clear Filters
                if (_searchQuery.isNotEmpty ||
                    _statusFilter != 'all' ||
                    _ownerFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _statusFilter = 'all';
                        _ownerFilter = null;
                      });
                      _onFilterChanged();
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshItems,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : _buildDataTable(),
          ),

          // Pagination
          if (!_isLoading && _items.isNotEmpty) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(
              label: Checkbox(
                value:
                    _selectedItemIds.length == _items.length &&
                    _items.isNotEmpty,
                onChanged: _onSelectAll,
              ),
            ),
            const DataColumn(label: Text('Photo')),
            const DataColumn(label: Text('Item Name')),
            const DataColumn(label: Text('Owner')),
            const DataColumn(label: Text('Borrower')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Borrow Date')),
            const DataColumn(label: Text('Due Date')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: _items.map((item) {
            final itemId = item['id'] as String;
            final isSelected = _selectedItemIds.contains(itemId);
            final status = item['status'] as String?;
            final isOverdue =
                status == 'borrowed' && (item['is_overdue'] as bool? ?? false);

            return DataRow(
              selected: isSelected,
              color: isOverdue
                  ? WidgetStateProperty.all(Colors.red.withOpacity(0.1))
                  : null,
              cells: [
                DataCell(
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _onItemSelected(itemId, value),
                  ),
                ),
                DataCell(_buildPhotoCell(item)),
                DataCell(Text(item['name'] as String? ?? 'N/A')),
                DataCell(_buildOwnerCell(item)),
                DataCell(Text(item['borrower_name'] as String? ?? '-')),
                DataCell(_buildStatusBadge(status, isOverdue)),
                DataCell(_buildDateCell(item['borrowed_at'])),
                DataCell(_buildDateCell(item['due_date'])),
                DataCell(_buildActionsCell(itemId)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPhotoCell(Map<String, dynamic> item) {
    final photoUrl = item['photo_url'] as String?;
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? const Icon(Icons.inventory_2, size: 20, color: Colors.grey)
          : null,
    );
  }

  Widget _buildOwnerCell(Map<String, dynamic> item) {
    final ownerName = item['owner_name'] as String? ?? 'N/A';
    final ownerEmail = item['owner_email'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(ownerName, style: const TextStyle(fontWeight: FontWeight.w500)),
        if (ownerEmail.isNotEmpty)
          Text(
            ownerEmail,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String? status, bool isOverdue) {
    Color backgroundColor;
    Color textColor;
    String label;

    if (isOverdue) {
      backgroundColor = Colors.red;
      textColor = Colors.white;
      label = 'OVERDUE';
    } else {
      switch (status) {
        case 'borrowed':
          backgroundColor = Colors.orange;
          textColor = Colors.white;
          label = 'BORROWED';
          break;
        case 'returned':
          backgroundColor = Colors.green;
          textColor = Colors.white;
          label = 'RETURNED';
          break;
        default:
          backgroundColor = Colors.grey;
          textColor = Colors.white;
          label = status?.toUpperCase() ?? 'UNKNOWN';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDateCell(dynamic date) {
    if (date == null) return const Text('-');

    try {
      final dateTime = DateTime.parse(date.toString());
      return Text(DateFormat('dd MMM yyyy').format(dateTime));
    } catch (e) {
      return const Text('-');
    }
  }

  Widget _buildActionsCell(String itemId) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.visibility, size: 20),
          onPressed: () => _handleViewItem(itemId),
          tooltip: 'View details',
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 20),
          onPressed: () => _handleEditItem(itemId),
          tooltip: 'Edit',
        ),
        IconButton(
          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
          onPressed: () => _handleDeleteItem(itemId),
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalItems / _pageSize).ceil();
    final canGoBack = _currentPage > 0;
    final canGoForward =
        _currentPage < totalPages - 1 && _items.length == _pageSize;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_currentPage * _pageSize + 1} - ${_currentPage * _pageSize + _items.length} items',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Row(
            children: [
              IconButton(
                onPressed: canGoBack
                    ? () => _onPageChanged(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${_currentPage + 1}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                onPressed: canGoForward
                    ? () => _onPageChanged(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
