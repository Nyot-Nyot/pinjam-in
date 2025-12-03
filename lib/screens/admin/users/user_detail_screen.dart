import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/admin/breadcrumbs.dart';
import '../../../widgets/admin/delete_user_dialog.dart';
import '../admin_layout.dart';

/// UserDetailScreen - Admin screen to view detailed user information
///
/// Features:
/// - Basic user info (name, email, role, status)
/// - Account info (created, updated, last login)
/// - Activity metrics (items count, borrowed, returned, overdue)
/// - User's items list (last 10)
/// - Admin actions (reset password, lock/unlock, change role, delete)
class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _supabase = Supabase.instance.client;

  // Data state
  Map<String, dynamic>? _userDetails;
  List<Map<String, dynamic>> _userItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    print('Loading user details for: ${widget.userId}');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call admin function to get user details
      final response = await _supabase.rpc(
        'admin_get_user_details',
        params: {'p_user_id': widget.userId},
      );

      print('User details response: $response');

      // Get user's items (last 10)
      final itemsResponse = await _supabase
          .from('items')
          .select('id, name, status, borrow_date, due_date, return_date')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _userDetails = response.isNotEmpty ? response[0] : null;
          _userItems = (itemsResponse as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        print('User details updated: ${_userDetails?['full_name']}');
      }
    } catch (e) {
      print('Error loading user details: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/users/${widget.userId}',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : _userDetails == null
          ? _buildNotFoundWidget()
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs
          Breadcrumbs(
            items: [
              BreadcrumbItem(label: 'Admin'),
              BreadcrumbItem(
                label: 'Users',
                onTap: () => Navigator.of(context).pushNamed('/admin/users'),
              ),
              BreadcrumbItem(label: _userDetails!['full_name'] ?? 'User'),
            ],
          ),
          const SizedBox(height: 16),

          // Header with actions
          _buildHeader(),
          const SizedBox(height: 16),

          // Responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              // Mobile layout (single column)
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    _buildBasicInfoSection(),
                    const SizedBox(height: 16),
                    _buildAccountInfoSection(),
                    const SizedBox(height: 16),
                    _buildActivityMetricsSection(),
                    const SizedBox(height: 16),
                    _buildUserItemsSection(),
                    const SizedBox(height: 16),
                    _buildActionsSection(),
                  ],
                );
              }

              // Desktop layout (two columns)
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column - Info sections
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildBasicInfoSection(),
                        const SizedBox(height: 16),
                        _buildAccountInfoSection(),
                        const SizedBox(height: 16),
                        _buildUserItemsSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right column - Metrics and actions
                  Expanded(
                    child: Column(
                      children: [
                        _buildActivityMetricsSection(),
                        const SizedBox(height: 16),
                        _buildActionsSection(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final fullName = _userDetails!['full_name'] as String? ?? 'Unknown';
    final email = _userDetails!['email'] as String? ?? 'No email';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile layout - vertical stacking
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name and email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Edit button full width on mobile
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    print('MOBILE Edit button pressed!');
                    _handleEditUser();
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit User'),
                ),
              ),
            ],
          );
        }

        // Desktop layout - horizontal
        return Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.blue,
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name and email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Edit button
            ElevatedButton.icon(
              onPressed: () {
                print('DESKTOP Edit button pressed!');
                _handleEditUser();
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit User'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBasicInfoSection() {
    final role = _userDetails!['role'] as String? ?? 'user';
    final status = _userDetails!['status'] as String? ?? 'active';
    final userId = _userDetails!['id'] as String? ?? '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildInfoRow('User ID', userId, mono: true),
            const SizedBox(height: 12),
            _buildInfoRow('Role', '', customValue: _buildRoleBadge(role)),
            const SizedBox(height: 12),
            _buildInfoRow('Status', '', customValue: _buildStatusBadge(status)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoSection() {
    final createdAt = _userDetails!['created_at'] != null
        ? DateTime.parse(_userDetails!['created_at'] as String)
        : null;
    final updatedAt = _userDetails!['updated_at'] != null
        ? DateTime.parse(_userDetails!['updated_at'] as String)
        : null;
    final lastLogin = _userDetails!['last_login'] != null
        ? DateTime.parse(_userDetails!['last_login'] as String)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildInfoRow(
              'Created',
              createdAt != null
                  ? DateFormat('MMM d, y \'at\' h:mm a').format(createdAt)
                  : '-',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Last Updated',
              updatedAt != null
                  ? DateFormat('MMM d, y \'at\' h:mm a').format(updatedAt)
                  : '-',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Last Login',
              lastLogin != null
                  ? DateFormat('MMM d, y \'at\' h:mm a').format(lastLogin)
                  : 'Never',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityMetricsSection() {
    final totalItems = _userDetails!['total_items'] as int? ?? 0;
    final borrowedItems = _userDetails!['borrowed_items'] as int? ?? 0;
    final returnedItems = _userDetails!['returned_items'] as int? ?? 0;
    final overdueItems = _userDetails!['overdue_items'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Metrics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildMetricCard(
              'Total Items',
              totalItems.toString(),
              Icons.inventory_2,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              'Borrowed',
              borrowedItems.toString(),
              Icons.arrow_upward,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              'Returned',
              returnedItems.toString(),
              Icons.check_circle,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildMetricCard(
              'Overdue',
              overdueItems.toString(),
              Icons.warning,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'User Items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _handleViewAllItems,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_userItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _userItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _userItems[index];
                  return _buildItemTile(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    final status = _userDetails!['status'] as String? ?? 'active';
    final isActive = status == 'active';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleResetPassword,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Reset Password'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleToggleAccountStatus,
                icon: Icon(isActive ? Icons.lock : Icons.lock_open),
                label: Text(isActive ? 'Lock Account' : 'Unlock Account'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleChangeRole,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Change Role'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleDeleteUser,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool mono = false,
    Widget? customValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              customValue ??
              Text(
                value,
                style: TextStyle(
                  fontFamily: mono ? 'monospace' : null,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Unknown';
    final status = item['status'] as String? ?? 'borrowed';
    final borrowDate = item['borrow_date'] != null
        ? DateTime.parse(item['borrow_date'] as String)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: status == 'returned' ? Colors.green[100] : Colors.orange[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          status == 'returned' ? Icons.check_circle : Icons.arrow_upward,
          color: status == 'returned' ? Colors.green : Colors.orange,
          size: 18,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        borrowDate != null
            ? 'Borrowed ${DateFormat('MMM d, y').format(borrowDate)}'
            : 'No date',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: _buildStatusBadge(status, small: true),
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = role == 'admin' ? Colors.purple : Colors.blue;
    final icon = role == 'admin' ? Icons.admin_panel_settings : Icons.person;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              role.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool small = false}) {
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
      case 'returned':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'borrowed':
        color = Colors.orange;
        icon = Icons.arrow_upward;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 11 : 13, color: color),
          SizedBox(width: small ? 2 : 4),
          Flexible(
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: small ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Failed to load user details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUserDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('User not found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'The user you are looking for does not exist.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/admin/users'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Users'),
          ),
        ],
      ),
    );
  }

  // Action handlers
  void _handleEditUser() async {
    print('Edit button clicked, navigating to edit screen...');

    // Show debug snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening edit screen...'),
        duration: Duration(seconds: 1),
      ),
    );

    final result = await Navigator.pushNamed(
      context,
      '/admin/users/${widget.userId}/edit',
    );

    print('Returned from edit screen with result: $result');

    // Show result in snackbar for debugging
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Returned with result: $result'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }

    // Reload data if user was updated
    if (result == true) {
      print('User was updated, reloading details...');
      if (mounted) {
        await _loadUserDetails();

        // Show reload confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data reloaded!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      print('No update or result is not true');
    }
  }

  void _handleViewAllItems() {
    // TODO: Navigate to items list filtered by user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('View all items - Coming soon')),
    );
  }

  void _handleResetPassword() async {
    if (_userDetails == null) return;

    final userEmail = _userDetails!['email'] as String? ?? '';
    final userName = _userDetails!['full_name'] ?? 'Unknown User';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send a password reset email to this user?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The user will receive an email with a link to reset their password.',
              style: Theme.of(context).textTheme.bodySmall,
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
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

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
                Text('Sending password reset email...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Send password reset email using regular Supabase Auth
      // This doesn't require admin API, just sends reset email to the user
      await _supabase.auth.resetPasswordForEmail(
        userEmail,
        redirectTo: 'io.supabase.pinjam_in://reset-password',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $userEmail'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Create audit log
      try {
        await _supabase.rpc(
          'admin_create_audit_log',
          params: {
            'p_action_type': 'reset_password',
            'p_table_name': 'profiles',
            'p_record_id': widget.userId,
            'p_metadata': {
              'email': userEmail,
              'admin_action': 'sent_reset_email',
            },
          },
        );
      } catch (auditError) {
        // Audit log failed but reset email was sent, just log it
        print('Failed to create audit log: $auditError');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _handleResetPassword,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleToggleAccountStatus() async {
    if (_userDetails == null) return;

    final status = _userDetails!['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final newStatus = isActive ? 'suspended' : 'active';
    final userName = _userDetails!['full_name'] ?? 'Unknown User';
    final userEmail = _userDetails!['email'] ?? '';

    // Show confirmation dialog with reason input
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: Text(isActive ? 'Lock Account' : 'Unlock Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    border: Border.all(
                      color: isActive ? Colors.orange : Colors.green,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.lock : Icons.lock_open,
                        color: isActive ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isActive
                      ? 'This will prevent the user from logging in. The user\'s data and items will be preserved.'
                      : 'This will allow the user to log in again and access their account.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText:
                        'Reason ${isActive ? "(required)" : "(optional)"}',
                    hintText: isActive
                        ? 'e.g., Policy violation, suspicious activity'
                        : 'e.g., Issue resolved, account verified',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                  maxLength: 200,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = reasonController.text.trim();
                if (isActive && text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please provide a reason for locking the account',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                reason = text.isEmpty ? null : text;
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.orange : Colors.green,
              ),
              child: Text(isActive ? 'Lock Account' : 'Unlock Account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('${isActive ? "Locking" : "Unlocking"} account...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Call admin_update_user_status RPC
      final response = await _supabase.rpc(
        'admin_update_user_status',
        params: {
          'p_user_id': widget.userId,
          'p_new_status': newStatus,
          'p_reason': reason,
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Extract message from response
      String message = 'Account status updated successfully';
      if (response is List && response.isNotEmpty) {
        message = response[0]['message'] as String? ?? message;
      } else if (response is Map) {
        message = response['message'] as String? ?? message;
      }

      // Reload user details to show updated state
      await _loadUserDetails();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _handleToggleAccountStatus,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleChangeRole() async {
    if (_userDetails == null) return;

    final currentRole = _userDetails!['role'] as String? ?? 'user';
    final userName = _userDetails!['full_name'] ?? 'Unknown User';
    final userEmail = _userDetails!['email'] ?? '';

    // Show role selection dialog
    String? selectedRole;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        String tempRole = currentRole;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select new role for this user:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Role options
                  RadioListTile<String>(
                    title: const Text('User'),
                    subtitle: const Text(
                      'Can borrow items and manage own profile',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: 'user',
                    groupValue: tempRole,
                    onChanged: (value) {
                      setState(() => tempRole = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Admin'),
                    subtitle: const Text(
                      'Full access to all features and data',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: 'admin',
                    groupValue: tempRole,
                    onChanged: (value) {
                      setState(() => tempRole = value!);
                    },
                  ),

                  // Warning for admin role
                  if (tempRole == 'admin' && currentRole != 'admin')
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        border: Border.all(color: Colors.orange, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin users have full access to all features and can modify any data.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
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
                  onPressed: tempRole == currentRole
                      ? null
                      : () {
                          selectedRole = tempRole;
                          Navigator.pop(context, true);
                        },
                  child: const Text('Change Role'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedRole == null || !mounted) return;

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
                Text('Updating role...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Call admin_update_user_role RPC
      final response = await _supabase.rpc(
        'admin_update_user_role',
        params: {'p_user_id': widget.userId, 'p_new_role': selectedRole},
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Extract message from response
      String message = 'User role updated successfully';
      if (response is List && response.isNotEmpty) {
        message = response[0]['message'] as String? ?? message;
      } else if (response is Map) {
        message = response['message'] as String? ?? message;
      }

      // Reload user details to show updated state
      await _loadUserDetails();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Retry', onPressed: _handleChangeRole),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleDeleteUser() async {
    if (_userDetails == null) return;

    final userName = _userDetails!['full_name'] ?? 'Unknown User';
    final userEmail = _userDetails!['email'] ?? '';
    final itemsCount = (_userDetails!['total_items'] ?? 0) as int;

    // Show delete dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DeleteUserDialog(
        userId: widget.userId,
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
          'p_user_id': widget.userId,
          'p_hard_delete': hardDelete,
          'p_reason': reason.isEmpty ? null : reason,
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show success message and navigate back
      final message = response[0]['message'] as String;
      Navigator.pushReplacementNamed(context, '/admin/users');

      // Show snackbar after navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Retry', onPressed: _handleDeleteUser),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
