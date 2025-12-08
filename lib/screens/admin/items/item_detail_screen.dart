import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/auth_provider.dart';
import '../../unauthorized_screen.dart';
import '../admin_layout.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _itemData;

  @override
  void initState() {
    super.initState();
    _loadItemDetails();
  }

  Future<void> _loadItemDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Debug: print current auth context and app profile
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      debugPrint('DEBUG: _loadItemDetails - currentUser.id=${currentUser?.id}');
      debugPrint(
        'DEBUG: _loadItemDetails - authProvider.profile.id=${context.read<AuthProvider>().profile?.id}',
      );
      debugPrint(
        'DEBUG: _loadItemDetails - authProvider.profile.role=${context.read<AuthProvider>().profile?.role}',
      );

      // Call RPC (project uses direct rpc(...) return values)
      final data = await _supabase.rpc(
        'admin_get_item_details',
        params: {'p_item_id': widget.itemId},
      );

      if (mounted) {
        setState(() {
          // RPC returns a List, get the first item
          if (data is List && data.isNotEmpty) {
            try {
              _itemData = Map<String, dynamic>.from(data.first as Map);
            } catch (_) {
              _itemData = data.first as Map<String, dynamic>?;
            }
          } else {
            _itemData = null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
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
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      return const UnauthorizedScreen();
    }

    // Jika profile masih loading atau belum ada, tampilkan loading spinner
    if (authProvider.isLoading || authProvider.profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Jika sudah pasti bukan admin, tampilkan UnauthorizedScreen
    if (!authProvider.isAdmin) {
      return const UnauthorizedScreen();
    }

    return AdminLayout(
      currentRoute: '/admin/items/${widget.itemId}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/admin'),
                  child: const Text('Admin'),
                ),
                const Text(' > '),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/admin/items'),
                  child: const Text('Items'),
                ),
                const Text(' > '),
                Text(
                  _isLoading
                      ? 'Loading...'
                      : (_itemData?['name'] ?? 'Item Details'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadItemDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_itemData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Item not found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/admin/items'),
              child: const Text('Back to Items List'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Info section
          _buildItemInfoSection(),
          const SizedBox(height: 16),

          // Borrower Info section
          _buildBorrowerInfoSection(),
          const SizedBox(height: 16),

          // Dates section
          _buildDatesSection(),
          const SizedBox(height: 16),

          // Owner Info section
          _buildOwnerInfoSection(),
          const SizedBox(height: 16),

          // History section
          _buildHistorySection(),
          const SizedBox(height: 16),

          // Admin Actions section
          _buildAdminActionsSection(),
        ],
      ),
    );
  }

  Widget _buildAdminActionsSection() {
    final status = _itemData!['status'] as String? ?? 'unknown';
    final photoUrl = _itemData!['photo_url'] as String?;
    final itemName = _itemData!['name'] as String? ?? 'Unknown Item';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Edit Item button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/admin/items/${widget.itemId}/edit',
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Item'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Mark as Returned button (only show if borrowed or overdue)
            if (status.toLowerCase() == 'borrowed' ||
                status.toLowerCase() == 'overdue') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleMarkAsReturned,
                  icon: const Icon(Icons.assignment_return),
                  label: const Text('Mark as Returned'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // View Photo Full Screen button (only if photo exists)
            if (photoUrl != null && photoUrl.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showFullScreenPhoto(photoUrl),
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('View Photo Full Screen'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Delete Item button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleDeleteItem(itemName),
                icon: const Icon(Icons.delete),
                label: const Text('Delete Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder action handlers
  Future<void> _handleMarkAsReturned() async {
    final itemName = _itemData!['name'] as String? ?? 'this item';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Returned'),
        content: Text('Are you sure you want to mark "$itemName" as returned?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Returned'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Marking as returned...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      await _supabase.rpc(
        'admin_update_item_status',
        params: {'p_item_id': widget.itemId, 'p_new_status': 'returned'},
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Reload item details
        await _loadItemDetails();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item marked as returned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _handleMarkAsReturned,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteItem(String itemName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$itemName"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The item will be permanently deleted.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
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

    if (confirmed != true) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting item...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final response = await _supabase.rpc(
        'admin_delete_item',
        params: {'p_item_id': widget.itemId},
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushReplacementNamed(
          context,
          '/admin/items',
        ); // Navigate back to list

        // Show success message after navigation
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  // If function returned a message, show it; otherwise generic
                  (response is String ? response : 'Item deleted successfully'),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleDeleteItem(itemName),
            ),
          ),
        );
      }
    }
  }

  Widget _buildItemInfoSection() {
    final photoUrl = _itemData!['photo_url'] as String?;
    final name = _itemData!['name'] as String? ?? 'Unknown Item';
    final status = _itemData!['status'] as String? ?? 'unknown';
    final notes = _itemData!['notes'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Photo
            if (photoUrl != null && photoUrl.isNotEmpty) ...[
              Center(
                child: GestureDetector(
                  onTap: () => _showFullScreenPhoto(photoUrl),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Center(
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Name
            _buildInfoRow('Item Name', name, isBold: true),
            const Divider(),

            // Status
            Row(
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                _buildStatusBadge(status),
              ],
            ),
            const Divider(),

            // Notes
            _buildInfoRow(
              'Notes',
              notes != null && notes.isNotEmpty ? notes : 'No notes',
              isMultiline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'borrowed':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.schedule;
        break;
      case 'returned':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle;
        break;
      case 'overdue':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.warning;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isMultiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showFullScreenPhoto(String photoUrl) {
    // TODO: Implement full screen photo view
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(child: Image.network(photoUrl)),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowerInfoSection() {
    final borrowerName = _itemData!['borrower_name'] as String?;
    final borrowerContact = _itemData!['borrower_contact_id'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Borrower Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Borrower Name
            _buildInfoRow(
              'Borrower Name',
              borrowerName != null && borrowerName.isNotEmpty
                  ? borrowerName
                  : 'Not specified',
            ),

            if (borrowerContact != null && borrowerContact.isNotEmpty) ...[
              const Divider(),
              // Contact Info
              _buildInfoRow('Contact ID', borrowerContact),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection() {
    final borrowDate = _itemData!['borrow_date'] as String?;
    final returnDate = _itemData!['return_date'] as String?;
    final status = _itemData!['status'] as String? ?? 'unknown';
    final daysBorrowed = _itemData!['days_borrowed'] as int?;
    final daysOverdue = _itemData!['days_overdue'] as int?;
    final isOverdue = _itemData!['is_overdue'] as bool? ?? false;

    return Card(
      color: isOverdue ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Dates & Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning,
                          size: 16,
                          color: Colors.red.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'OVERDUE',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Borrow Date
            _buildInfoRow(
              'Borrow Date',
              borrowDate != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(borrowDate))
                  : 'Not specified',
            ),
            const Divider(),

            // Due Date (calculated from return_date in schema)
            _buildInfoRow(
              'Due Date',
              returnDate != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.parse(returnDate))
                  : 'Not specified',
            ),

            // Return Date (only show if status is returned)
            if (status.toLowerCase() == 'returned') ...[
              const Divider(),
              _buildInfoRow(
                'Actual Return Date',
                returnDate != null
                    ? DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.parse(returnDate))
                    : 'Not specified',
              ),
            ],

            // Days borrowed
            if (daysBorrowed != null) ...[
              const Divider(),
              _buildInfoRow(
                'Days Borrowed',
                '$daysBorrowed ${daysBorrowed == 1 ? 'day' : 'days'}',
              ),
            ],

            // Days overdue (only show if overdue)
            if (isOverdue && daysOverdue != null) ...[
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Days Overdue',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '$daysOverdue ${daysOverdue == 1 ? 'day' : 'days'}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerInfoSection() {
    final userId = _itemData!['user_id'] as String?;
    final ownerName = _itemData!['owner_name'] as String? ?? 'Unknown';
    final ownerEmail = _itemData!['owner_email'] as String? ?? 'Not specified';
    final ownerRole = _itemData!['owner_role'] as String? ?? 'user';
    final ownerStatus = _itemData!['owner_status'] as String? ?? 'active';
    final ownerTotalItems = _itemData!['owner_total_items'] as int? ?? 0;
    final ownerBorrowedItems = _itemData!['owner_borrowed_items'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Owner Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Owner Name (linkable)
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Owner Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: userId != null
                        ? () => Navigator.pushNamed(
                            context,
                            '/admin/users/$userId',
                          )
                        : null,
                    child: Row(
                      children: [
                        Text(
                          ownerName,
                          style: TextStyle(
                            color: userId != null ? Colors.blue : Colors.black,
                            decoration: userId != null
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                        if (userId != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Owner Email
            _buildInfoRow('Email', ownerEmail),
            const Divider(),

            // Owner Role
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Role',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ownerRole.toLowerCase() == 'admin'
                          ? Colors.purple.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ownerRole.toUpperCase(),
                      style: TextStyle(
                        color: ownerRole.toLowerCase() == 'admin'
                            ? Colors.purple.shade900
                            : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Owner Status
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildOwnerStatusBadge(ownerStatus)),
              ],
            ),
            const Divider(),

            // Owner Stats
            _buildInfoRow(
              'Total Items',
              '$ownerTotalItems ${ownerTotalItems == 1 ? 'item' : 'items'}',
            ),
            const Divider(),
            _buildInfoRow(
              'Currently Borrowed',
              '$ownerBorrowedItems ${ownerBorrowedItems == 1 ? 'item' : 'items'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle;
        break;
      case 'inactive':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
        icon = Icons.remove_circle;
        break;
      case 'suspended':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.block;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final createdAt = _itemData!['created_at'] as String?;
    final itemId = _itemData!['id'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Item ID
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Item ID',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    itemId ?? 'Unknown',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Created Date
            _buildInfoRow(
              'Created',
              createdAt != null
                  ? DateFormat(
                      'dd MMM yyyy \'at\' h:mm a',
                    ).format(DateTime.parse(createdAt))
                  : 'Not available',
            ),
          ],
        ),
      ),
    );
  }
}
