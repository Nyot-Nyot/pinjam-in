import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/admin/breadcrumbs.dart';
import '../../../widgets/admin/delete_user_dialog.dart';
import '../admin_layout.dart';

/// UsersListScreen - Admin screen to view and manage all users
///
/// Features:
/// - Data table with user information
/// - Search by name/email
/// - Filter by role and status
/// - Sort by multiple fields
/// - Pagination (20 users per page)
/// - Bulk actions (status update, delete)
class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final _supabase = Supabase.instance.client;

  // Data state
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 20;
  int _totalUsers = 0;

  // Search & Filters
  String _searchQuery = '';
  String _roleFilter = 'all'; // all, user, admin
  String _statusFilter = 'all'; // all, active, inactive, suspended

  // Note: Sorting is handled by backend (ORDER BY updated_at DESC)
  // Client-side sorting is not supported by current RPC function

  // Bulk selection
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    debugPrint('_loadUsers called, fetching from database...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Calculate offset
      final offset = _currentPage * _pageSize;

      // Call admin function to get users
      final response = await _supabase.rpc(
        'admin_get_all_users',
        params: {
          'p_limit': _pageSize,
          'p_offset': offset,
          'p_search': _searchQuery.isEmpty ? null : _searchQuery,
          'p_role_filter': _roleFilter == 'all' ? null : _roleFilter,
          'p_status_filter': _statusFilter == 'all' ? null : _statusFilter,
        },
      );

      // Parse response
      final List<dynamic> usersList = response as List;

      debugPrint('Fetched ${usersList.length} users from database');
      if (usersList.isNotEmpty) {
        debugPrint(
          'First user: ${usersList[0]['full_name']} (${usersList[0]['email']})',
        );
      }

      // Note: Sorting is done on the database side (ORDER BY updated_at DESC)
      // Client-side sorting is not supported by this RPC function

      // Get total count for pagination
      // Note: You may need to create a separate function to get total count
      // For now, we'll estimate based on returned data

      setState(() {
        _users = usersList.cast<Map<String, dynamic>>();
        _totalUsers = _users.isNotEmpty
            ? (_currentPage + 2) * _pageSize
            : _currentPage * _pageSize;
        _isLoading = false;
        _selectedUserIds.clear(); // Clear selection on reload
      });

      debugPrint('Users list updated in state, should trigger rebuild');
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 0; // Reset to first page
    });
    _loadUsers();
  }

  void _onRoleFilterChanged(String? role) {
    if (role == null) return;
    setState(() {
      _roleFilter = role;
      _currentPage = 0;
    });
    _loadUsers();
  }

  void _onStatusFilterChanged(String? status) {
    if (status == null) return;
    setState(() {
      _statusFilter = status;
      _currentPage = 0;
    });
    _loadUsers();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadUsers();
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/users',
      breadcrumbs: const [
        BreadcrumbItem(label: 'Admin'),
        BreadcrumbItem(label: 'Users'),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage all users in the system',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/admin/users/create');
                },
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
              ),
            ],
          ),
        ),

        // Search and Filters
        _buildSearchAndFilters(),

        // Bulk Actions
        if (_selectedUserIds.isNotEmpty) _buildBulkActions(),

        // Data Table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildDataTable(),
          ),
        ),

        // Pagination
        _buildPagination(),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load users',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // Search bar - full width
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
            onSubmitted: _onSearch,
          ),
          const SizedBox(height: 12),

          // Filters row
          Row(
            children: [
              // Role filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _roleFilter,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: _onRoleFilterChanged,
                ),
              ),
              const SizedBox(width: 16),

              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended'),
                    ),
                  ],
                  onChanged: _onStatusFilterChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          Flexible(
            child: Text(
              '${_selectedUserIds.length} selected',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _handleBulkStatusUpdate,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Status', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _handleBulkDelete,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No users found',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: true,
          columns: [
            const DataColumn(
              label: Text('User'),
              // Sorting disabled: backend function uses fixed ORDER BY updated_at DESC
            ),
            const DataColumn(label: Text('Email')),
            const DataColumn(label: Text('Role')),
            const DataColumn(label: Text('Status')),
            const DataColumn(
              label: Text('Items'),
              numeric: true,
              // Sorting disabled: backend function uses fixed ORDER BY updated_at DESC
            ),
            const DataColumn(
              label: Text('Updated'),
              // Sorting disabled: backend function uses fixed ORDER BY updated_at DESC
            ),
            const DataColumn(label: Text('Actions')),
          ],
          rows: _users.map((user) => _buildUserRow(user)).toList(),
        ),
      ),
    );
  }

  DataRow _buildUserRow(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final fullName = user['full_name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? 'No email';
    final role = user['role'] as String? ?? 'user';
    final status = user['status'] as String? ?? 'active';
    final itemsCount = user['items_count'] as int? ?? 0;
    final updatedAt = user['updated_at'] != null
        ? DateTime.parse(user['updated_at'] as String)
        : null;

    return DataRow(
      selected: _selectedUserIds.contains(userId),
      onSelectChanged: (_) => _toggleUserSelection(userId),
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(fullName),
            ],
          ),
        ),
        DataCell(Text(email)),
        DataCell(_buildRoleBadge(role)),
        DataCell(_buildStatusBadge(status)),
        DataCell(Text(itemsCount.toString())),
        DataCell(
          Text(
            updatedAt != null ? DateFormat('MMM d, y').format(updatedAt) : '-',
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                tooltip: 'View',
                onPressed: () => _handleViewUser(userId),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit',
                onPressed: () => _handleEditUser(userId),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _handleDeleteUser(userId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    IconData icon;

    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        break;
      case 'user':
      default:
        color = Colors.blue;
        icon = Icons.person;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'inactive':
        color = Colors.grey;
        icon = Icons.remove_circle;
        break;
      case 'suspended':
        color = Colors.red;
        icon = Icons.block;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalUsers / _pageSize).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Showing ${_currentPage * _pageSize + 1}-${(_currentPage + 1) * _pageSize > _totalUsers ? _totalUsers : (_currentPage + 1) * _pageSize} of $_totalUsers',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _currentPage > 0
                    ? () => _onPageChanged(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => _onPageChanged(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Action handlers
  void _handleViewUser(String userId) {
    Navigator.pushNamed(context, '/admin/users/$userId');
  }

  void _handleEditUser(String userId) async {
    // Show debug snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening edit for user: $userId'),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await Navigator.pushNamed(
      context,
      '/admin/users/$userId/edit',
    );

    // If widget unmounted while on edit screen, bail out
    if (!mounted) return;

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Edit returned with: $result (type: ${result.runtimeType})',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );

    // Reload list if user was updated
    if (result == true) {
      debugPrint('Result is true, reloading users...');
      if (!mounted) return;
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User list reloaded!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      debugPrint('Result is NOT true: $result');
    }
  }

  void _handleDeleteUser(String userId) async {
    // Find user data for dialog
    final user = _users.firstWhere((u) => u['id'] == userId);
    final userName = user['full_name'] ?? 'Unknown User';
    final userEmail = user['email'] ?? '';
    final itemsCount = (user['items_count'] ?? 0) as int;

    // Show delete dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DeleteUserDialog(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        itemsCount: itemsCount,
      ),
    );

    if (result == null || !mounted) return;

    final hardDelete = result['hardDelete'] as bool;
    final reason = result['reason'] as String;

    // Show loading dialog
    if (!mounted) return;
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
                Text('Deleting user...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Call delete RPC
      final response = await _supabase.rpc(
        'admin_delete_user',
        params: {
          'p_user_id': userId,
          'p_hard_delete': hardDelete,
          'p_reason': reason.isEmpty ? null : reason,
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success message
      final message = response[0]['message'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );

      // Reload users
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _handleDeleteUser(userId),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleBulkStatusUpdate() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update status for ${_selectedUserIds.length} user(s)?'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'New Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
              ],
              onChanged: (value) {
                // Store selected status
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement bulk status update
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bulk update coming soon...')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _handleBulkDelete() async {
    if (_selectedUserIds.isEmpty) return;

    final selectedCount = _selectedUserIds.length;

    // Confirm bulk delete
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to deactivate $selectedCount user(s)?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will perform soft delete (deactivate users).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                'Note: Bulk delete always uses soft delete for safety. Use individual delete for permanent removal.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Deleting 0 of $selectedCount users...'),
          ],
        ),
      ),
    );

    int successCount = 0;
    int failCount = 0;
    final List<String> errors = [];
    final userIdsList = _selectedUserIds.toList(); // Convert Set to List

    // Delete users one by one
    for (int i = 0; i < userIdsList.length; i++) {
      final userId = userIdsList[i];

      try {
        await _supabase.rpc(
          'admin_delete_user',
          params: {
            'p_user_id': userId,
            'p_hard_delete': false, // Always soft delete for bulk
            'p_reason': 'Bulk delete operation',
          },
        );
        successCount++;

        // Update progress
        if (mounted) {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Deleting ${i + 1} of $selectedCount users...'),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        failCount++;
        errors.add('User $userId: ${e.toString()}');
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // Close progress dialog

    // Show result
    final resultMessage = successCount == selectedCount
        ? 'Successfully deactivated $successCount user(s)'
        : 'Completed: $successCount succeeded, $failCount failed';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultMessage),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 5),
        action: failCount > 0
            ? SnackBarAction(
                label: 'View Errors',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Errors'),
                      content: SingleChildScrollView(
                        child: Text(errors.join('\n\n')),
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
              )
            : null,
      ),
    );

    // Clear selection and reload
    setState(() {
      _selectedUserIds.clear();
    });
    await _loadUsers();
  }
}
