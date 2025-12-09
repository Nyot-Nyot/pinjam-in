import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/storage_keys.dart';
import '../../../providers/persistence_provider.dart';
import '../../admin/admin_layout.dart';

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({super.key});

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Form fields
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;

  final _nameController = TextEditingController();
  final _borrowerController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _borrowDate;
  DateTime? _dueDate;

  File? _pickedImage;
  bool _isSubmitting = false;
  bool _showUserList = false;
  // controller for the debug autocomplete field (not used in production)

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _borrowDate = DateTime.now();
  }

  String _userDisplay(Map<String, dynamic> u) {
    final name = (u['full_name'] as String?)?.trim();
    final email = (u['email'] as String?)?.trim();
    if ((name?.isNotEmpty ?? false) && (email?.isNotEmpty ?? false)) {
      return '$name <$email>';
    }
    if (name?.isNotEmpty ?? false) return name!;
    if (email?.isNotEmpty ?? false) return email!;
    return u['id'] as String? ?? '';
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final response = await _supabase.rpc(
        'admin_get_all_users',
        params: {
          'p_limit': 100,
          'p_offset': 0,
          'p_search': null,
          'p_role_filter': null,
          'p_status_filter': null,
        },
      );
      // Debugging: handle multiple RPC return shapes and print a summary
      debugPrint(
        '[CreateItem] admin_get_all_users response type: ${response.runtimeType}',
      );
      debugPrint(
        '[CreateItem] raw response (first 2 items or value): ${response is List ? response.take(2).toList() : response}',
      );

      List<Map<String, dynamic>> parsed = [];
      if (response is List) {
        parsed = response.cast<Map<String, dynamic>>();
      } else if (response is Map && response['data'] is List) {
        parsed = (response['data'] as List).cast<Map<String, dynamic>>();
      } else if (response is Map) {
        // Some RPC wrappers return { data: [...] } or { result: [...] }
        final maybeList = response.values.firstWhere(
          (v) => v is List,
          orElse: () => null,
        );
        if (maybeList is List) parsed = maybeList.cast<Map<String, dynamic>>();
      }

      if (parsed.isNotEmpty) {
        debugPrint(
          '[CreateItem] Parsed ${parsed.length} users, first: ${parsed.first}',
        );
      } else {
        debugPrint('[CreateItem] No users parsed from RPC');
      }

      setState(() {
        _users = parsed;
        if (_users.isNotEmpty) {
          _selectedUserId = _users.first['id'] as String?;
        }
      });
      // Fallback: if RPC returned nothing, try selecting directly from profiles
      if (parsed.isEmpty) {
        try {
          final direct = await _supabase
              .from('profiles')
              .select('id,full_name,email')
              .limit(1000);
          if (direct.isNotEmpty) {
            setState(() {
              _users = direct.cast<Map<String, dynamic>>();
              if (_users.isNotEmpty) {
                _selectedUserId = _users.first['id'] as String?;
              }
            });
            debugPrint(
              '[CreateItem] Fallback: loaded ${_users.length} users from profiles table',
            );
          } else {
            debugPrint('[CreateItem] Fallback: profiles query returned empty');
          }
        } catch (e) {
          debugPrint('[CreateItem] Fallback profiles query failed: $e');
        }
      }
    } catch (e) {
      // ignore - show empty list
      debugPrint('[CreateItem] Error loading users RPC: $e');
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile != null) {
      setState(() => _pickedImage = File(xfile.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an owner')));
      return;
    }

    setState(() => _isSubmitting = true);

    final id = const Uuid().v4();
    String? photoUrl;

    try {
      final persistence = context.read<PersistenceProvider>().service;
      if (_pickedImage != null && persistence != null) {
        try {
          photoUrl = await persistence.uploadImage(_pickedImage!.path, id);
        } catch (e) {
          // continue without photo but log
          debugPrint('Image upload failed: $e');
        }
      }

      final nowIso = DateTime.now().toIso8601String();

      final item = {
        'id': id,
        'user_id': _selectedUserId,
        'name': _nameController.text.trim(),
        'borrower_name': _borrowerController.text.trim().isEmpty
            ? null
            : _borrowerController.text.trim(),
        'borrower_contact_id': _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        'borrow_date': _borrowDate?.toIso8601String(),
        'due_date': _dueDate?.toIso8601String(),
        'status': 'borrowed',
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'photo_url': photoUrl,
        'created_at': nowIso,
      };

      // Insert item record
      final insertRes = await _supabase
          .from(StorageKeys.itemsTable)
          .insert(item)
          .select();
      // use insertRes to avoid analyzer unused-local warning and log result
      debugPrint('CreateItem: insertRes=$insertRes');

      // Create audit log via RPC (optional)
      try {
        await _supabase.rpc(
          'admin_create_audit_log',
          params: {
            'p_action_type': 'CREATE',
            'p_table_name': 'items',
            'p_record_id': id,
            'p_old_values': null,
            'p_new_values': jsonEncode(item),
            'p_metadata': jsonEncode({'created_via': 'admin_ui'}),
          },
        );
      } catch (e) {
        debugPrint('Failed to create audit log: $e');
      }

      // Navigate to item detail
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item created successfully')),
        );
        Navigator.pushReplacementNamed(context, '/admin/items');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating item: $e')));
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
      currentRoute: '/admin/items/create',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Create Item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Owner selector (searchable)
                      _loadingUsers
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Owner'),
                                const SizedBox(height: 8),
                                Autocomplete<String>(
                                  // Build display strings for users
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                        if (textEditingValue.text == '') {
                                          return _users
                                              .map((u) => _userDisplay(u))
                                              .take(10)
                                              .toList();
                                        }
                                        return _users
                                            .map((u) => _userDisplay(u))
                                            .where(
                                              (option) =>
                                                  option.toLowerCase().contains(
                                                    textEditingValue.text
                                                        .toLowerCase(),
                                                  ),
                                            )
                                            .take(10)
                                            .toList();
                                      },
                                  displayStringForOption: (option) => option,
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        // If we already have a selection, show it
                                        if (_selectedUserId != null &&
                                            controller.text.isEmpty) {
                                          final current = _users.firstWhere(
                                            (u) => u['id'] == _selectedUserId,
                                            orElse: () => <String, dynamic>{},
                                          );
                                          if (current.isNotEmpty) {
                                            controller.text = _userDisplay(
                                              current,
                                            );
                                          }
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Search owner by name or email',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          validator: (v) {
                                            if ((_selectedUserId == null) ||
                                                v == null ||
                                                v.trim().isEmpty) {
                                              return 'Please select an owner';
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                  onSelected: (selected) {
                                    final found = _users.firstWhere(
                                      (u) =>
                                          _userDisplay(u).toLowerCase() ==
                                          selected.toLowerCase(),
                                      orElse: () => <String, dynamic>{},
                                    );
                                    if (found.isNotEmpty) {
                                      setState(
                                        () => _selectedUserId =
                                            found['id'] as String?,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_selectedUserId != null)
                                  Text(
                                    'Selected owner: ${_users.firstWhere((u) => u['id'] == _selectedUserId)['full_name'] ?? _users.firstWhere((u) => u['id'] == _selectedUserId)['email']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                // Debug controls: reload and show list
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: _loadUsers,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Reload users'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _showUserList = !_showUserList,
                                      ),
                                      child: Text(
                                        _showUserList
                                            ? 'Hide users'
                                            : 'Show users',
                                      ),
                                    ),
                                  ],
                                ),
                                if (_showUserList)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: _users.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('No users loaded'),
                                          )
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _users.length,
                                            itemBuilder: (context, idx) {
                                              final u = _users[idx];
                                              return ListTile(
                                                dense: true,
                                                title: Text(_userDisplay(u)),
                                                subtitle: Text(u['id'] ?? ''),
                                                onTap: () => setState(() {
                                                  _selectedUserId =
                                                      u['id'] as String?;
                                                }),
                                              );
                                            },
                                          ),
                                  ),
                              ],
                            ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Item name',
                        ),
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'Please enter a name (min 3 chars)'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _borrowerController,
                              decoration: const InputDecoration(
                                labelText: 'Borrower name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _contactController,
                              decoration: const InputDecoration(
                                labelText: 'Borrower contact (optional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _borrowDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _borrowDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Borrow date',
                                ),
                                child: Text(
                                  _borrowDate == null
                                      ? 'Select'
                                      : DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_borrowDate!),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _dueDate ??
                                      DateTime.now().add(
                                        const Duration(days: 7),
                                      ),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _dueDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due date',
                                ),
                                child: Text(
                                  _dueDate == null
                                      ? 'Select'
                                      : DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_dueDate!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Photo picker
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Pick photo'),
                          ),
                          const SizedBox(width: 12),
                          if (_pickedImage != null)
                            Expanded(
                              child: Text(
                                'Selected: ${_pickedImage!.path.split('/').last}',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const CircularProgressIndicator.adaptive()
                              : const Text('Create Item'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
