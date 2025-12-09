import 'package:flutter/material.dart';
import 'package:pinjam_in/screens/admin/admin_layout.dart';
import 'package:pinjam_in/widgets/admin/breadcrumbs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditUserScreen extends StatefulWidget {
  final String userId;

  const EditUserScreen({super.key, required this.userId});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();

  String _selectedRole = 'user';
  String _selectedStatus = 'active';

  // Store original values to detect changes
  String _originalEmail = '';
  String _originalFullName = '';
  String _originalRole = 'user';
  String _originalStatus = 'active';

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Call admin_get_user_details RPC function
      final response = await supabase.rpc(
        'admin_get_user_details',
        params: {'p_user_id': widget.userId},
      );

      if (response == null || (response is List && response.isEmpty)) {
        throw Exception('User not found');
      }

      // RPC returns a list, get the first element
      final userData = response is List ? response[0] : response;

      setState(() {
        _userData = userData as Map<String, dynamic>;

        // Populate form fields with existing data
        _emailController.text = _userData!['email'] ?? '';
        _fullNameController.text = _userData!['full_name'] ?? '';
        _selectedRole = _userData!['role'] ?? 'user';
        _selectedStatus = _userData!['status'] ?? 'active';

        // Store original values to detect changes
        _originalEmail = _emailController.text;
        _originalFullName = _fullNameController.text;
        _originalRole = _selectedRole;
        _originalStatus = _selectedStatus;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUpdate() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;

      // Detect changes
      final email = _emailController.text.trim();
      final fullName = _fullNameController.text.trim();
      final emailChanged = email != _originalEmail;
      final fullNameChanged = fullName != _originalFullName;
      final roleChanged = _selectedRole != _originalRole;
      final statusChanged = _selectedStatus != _originalStatus;

      debugPrint('=== CHANGE DETECTION ===');
      debugPrint(
        'Email: "$_originalEmail" → "$email" (changed: $emailChanged)',
      );
      debugPrint(
        'Full Name: "$_originalFullName" → "$fullName" (changed: $fullNameChanged)',
      );
      debugPrint(
        'Role: "$_originalRole" → "$_selectedRole" (changed: $roleChanged)',
      );
      debugPrint(
        'Status: "$_originalStatus" → "$_selectedStatus" (changed: $statusChanged)',
      );

      // Check if anything changed
      if (!emailChanged && !fullNameChanged && !roleChanged && !statusChanged) {
        debugPrint('No changes detected, returning...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes detected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      // Update role if changed
      if (roleChanged) {
        await supabase.rpc(
          'admin_update_user_role',
          params: {'p_user_id': widget.userId, 'p_new_role': _selectedRole},
        );
      }

      // Update status if changed
      if (statusChanged) {
        await supabase.rpc(
          'admin_update_user_status',
          params: {
            'p_user_id': widget.userId,
            'p_new_status': _selectedStatus,
            'p_reason': 'Admin update via edit form',
          },
        );
      }

      // Update email or full_name if changed
      if (emailChanged || fullNameChanged) {
        // Update auth.users email if email changed
        if (emailChanged) {
          await supabase.auth.admin.updateUserById(
            widget.userId,
            attributes: AdminUserAttributes(email: email),
          );
        }

        // Update profiles full_name if changed
        if (fullNameChanged) {
          debugPrint(
            'Updating full_name from "$_originalFullName" to "$fullName"',
          );
          debugPrint('User ID: ${widget.userId}');

          // Use RPC with SECURITY DEFINER to bypass RLS
          try {
            await supabase.rpc(
              'admin_update_user_profile',
              params: {'p_user_id': widget.userId, 'p_full_name': fullName},
            );

            debugPrint('Profile updated successfully via RPC');
          } catch (e) {
            debugPrint('Error updating profile: $e');
            rethrow;
          }
          // Create audit log for full_name change
          await supabase.from('audit_logs').insert({
            'admin_user_id': supabase.auth.currentUser!.id,
            'action_type': 'update',
            'table_name': 'profiles',
            'record_id': widget.userId,
            'old_values': {'full_name': _originalFullName},
            'new_values': {'full_name': fullName},
          });
        }

        // Create audit log for email change
        if (emailChanged) {
          await supabase.from('audit_logs').insert({
            'admin_user_id': supabase.auth.currentUser!.id,
            'action_type': 'update',
            'table_name': 'auth.users',
            'record_id': widget.userId,
            'old_values': {'email': _originalEmail},
            'new_values': {'email': email},
          });
        }
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back with result to trigger reload
        debugPrint('Edit successful, popping with result true');
        Navigator.of(context).pop(true);
        debugPrint('Pop called');
      }
    } on PostgrestException catch (e) {
      // Database errors (RLS policy violations, constraint violations, etc.)
      String errorMessage = 'Database error occurred';

      if (e.message.contains('permission denied') ||
          e.message.contains('insufficient_privilege')) {
        errorMessage = 'You don\'t have permission to update users';
      } else if (e.message.contains('violates foreign key constraint')) {
        errorMessage = 'Invalid user reference';
      } else if (e.message.contains('duplicate key')) {
        errorMessage = 'Email already exists';
      } else {
        errorMessage = 'Failed to update user: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleUpdate,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on AuthException catch (e) {
      // Authentication errors (invalid token, expired session, etc.)
      String errorMessage = 'Authentication error occurred';

      if (e.message.contains('expired') || e.message.contains('invalid')) {
        errorMessage = 'Your session has expired. Please login again';
      } else if (e.message.contains('not authorized') ||
          e.message.contains('unauthorized')) {
        errorMessage = 'You are not authorized to perform this action';
      } else if (e.message.contains('Email rate limit exceeded')) {
        errorMessage = 'Too many email updates. Please try again later';
      } else {
        errorMessage = 'Failed to update user: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleUpdate,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Generic errors (network errors, unexpected errors, etc.)
      String errorMessage = 'An unexpected error occurred';

      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException') ||
          e.toString().contains('Failed host lookup')) {
        errorMessage =
            'Network error. Please check your connection and try again';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timeout. Please try again';
      } else {
        errorMessage = 'Failed to update user: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleUpdate,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/users/${widget.userId}/edit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs
          Breadcrumbs(
            items: [
              BreadcrumbItem(
                label: 'Admin',
                onTap: () => Navigator.of(context).pushNamed('/admin'),
              ),
              BreadcrumbItem(
                label: 'Users',
                onTap: () => Navigator.of(context).pushNamed('/admin/users'),
              ),
              const BreadcrumbItem(label: 'Edit User'),
            ],
          ),
          const SizedBox(height: 16),

          // Back button and title
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Edit User',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadUserData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Center form on desktop, full width on mobile
        final maxWidth = constraints.maxWidth > 600
            ? 600.0
            : constraints.maxWidth;

        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // User ID (readonly)
                        TextFormField(
                          initialValue: widget.userId,
                          decoration: const InputDecoration(
                            labelText: 'User ID',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.fingerprint),
                          ),
                          enabled: false,
                        ),
                        const SizedBox(height: 16),

                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                            hintText: 'Enter full name',
                          ),
                          validator: (value) {
                            // Full name is optional, no validation needed
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email (editable with warning)
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                            hintText: 'Enter email address',
                            helperText:
                                'Changing email will require user to verify new email',
                            helperMaxLines: 2,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required';
                            }
                            // Email format validation
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Role dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.admin_panel_settings),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('User'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Status dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.toggle_on),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                            DropdownMenuItem(
                              value: 'suspended',
                              child: Text('Suspended'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // Password note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withAlpha((0.3 * 255).round()),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Password cannot be changed here. Use "Reset Password" action on user detail page.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleUpdate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Update User',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
