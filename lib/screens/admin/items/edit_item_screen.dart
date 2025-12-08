import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_constants.dart';
import '../../../constants/storage_keys.dart';
import '../../../providers/persistence_provider.dart';
import '../../admin/admin_layout.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;
  const EditItemScreen({super.key, required this.itemId});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _borrowerController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _borrowDate;
  DateTime? _dueDate;
  String? _status;
  String? _ownerInitialDisplay;

  File? _pickedImage;
  String? _existingPhotoUrl;
  bool _removePhoto = false;
  // owner selection
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;
  bool _showUserList = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  Map<String, dynamic>? _originalValues;

  @override
  void initState() {
    super.initState();
    _loadItem();
    _loadUsers();
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
      List<Map<String, dynamic>> parsed = [];
      if (response is List) {
        parsed = response.cast<Map<String, dynamic>>();
      } else if (response is Map && response['data'] is List) {
        parsed = (response['data'] as List).cast<Map<String, dynamic>>();
      } else if (response is Map) {
        final maybeList = response.values.firstWhere(
          (v) => v is List,
          orElse: () => null,
        );
        if (maybeList is List) parsed = maybeList.cast<Map<String, dynamic>>();
      }

      if (parsed.isNotEmpty) {
        setState(() {
          _users = parsed;
        });
      } else {
        // fallback to profiles
        try {
          final direct = await _supabase
              .from('profiles')
              .select('id,full_name,email')
              .limit(1000);
          if (direct != null) {
            setState(
              () => _users = (direct as List).cast<Map<String, dynamic>>(),
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('EditItem: loadUsers failed $e');
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  /// Extract storage path from a Supabase storage URL.
  String? _extractStoragePath(String photoUrl) {
    try {
      if (photoUrl.contains('/storage/v1/object/')) {
        final parts = photoUrl.split('/storage/v1/object/');
        if (parts.length > 1) {
          final afterObject = parts[1];
          final pathParts = afterObject.split('/');
          // pathParts like ['public', 'item_photos', 'user_id', 'file.jpg']
          if (pathParts.length > 2) {
            final storagePath = pathParts.sublist(2).join('/');
            if (storagePath.contains('?')) return storagePath.split('?')[0];
            return storagePath;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadItem() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from(StorageKeys.itemsTable)
          .select()
          .eq('id', widget.itemId)
          .maybeSingle();
      if (res == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item not found')));
        if (mounted) Navigator.pop(context);
        return;
      }

      // store original values for audit
      _originalValues = Map<String, dynamic>.from(res);

      _nameController.text = (res['name'] ?? '') as String;
      // prefill selected owner id from the item so we don't accidentally send null
      _selectedUserId = res['user_id'] as String?;
      // try to fetch owner display name from profiles so we can prefill the Autocomplete
      try {
        if (_selectedUserId != null) {
          final ownerId = _selectedUserId!;
          final prof = await _supabase
              .from('profiles')
              .select('id,full_name,email')
              .eq('id', ownerId)
              .maybeSingle();
          if (prof is Map<String, dynamic> && prof.isNotEmpty) {
            _ownerInitialDisplay = _userDisplay(prof);
          }
        }
      } catch (_) {}
      _borrowerController.text = (res['borrower_name'] ?? '') as String;
      _contactController.text = (res['borrower_contact_id'] ?? '') as String;
      _notesController.text = (res['notes'] ?? '') as String;

      _existingPhotoUrl = res['photo_url'] as String?;
      _status = res['status'] as String?;
      // Ensure loaded status is one of DB-allowed values; fallback to 'borrowed'
      final allowed = [
        AppConstants.statusBorrowed,
        AppConstants.statusReturned,
      ];
      if (_status == null || !allowed.contains(_status)) {
        _status = AppConstants.statusBorrowed;
      }
      _borrowDate = res['borrow_date'] != null
          ? DateTime.parse(res['borrow_date'] as String)
          : null;
      _dueDate = res['due_date'] != null
          ? DateTime.parse(res['due_date'] as String)
          : null;
    } catch (e) {
      debugPrint('EditItem: load failed $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load item: $e')));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile != null) setState(() => _pickedImage = File(xfile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      // prepare update payload
      String? newPhotoUrl = _existingPhotoUrl;

      final persistence = context.read<PersistenceProvider>().service;
      if (_pickedImage != null && persistence != null) {
        try {
          final id = widget.itemId;
          newPhotoUrl = await persistence.uploadImage(_pickedImage!.path, id);
        } catch (e) {
          debugPrint('EditItem: image upload failed $e');
        }
      }

      // Photo removal logic: if user chose to remove and didn't upload a new one
      if (_removePhoto && _pickedImage == null && _existingPhotoUrl != null) {
        final path = _extractStoragePath(_existingPhotoUrl!);
        if (path != null && path.isNotEmpty) {
          try {
            await _supabase.storage.from(StorageKeys.imagesBucket).remove([
              path,
            ]);
          } catch (e) {
            debugPrint('EditItem: remove existing photo failed: $e');
          }
        }
        newPhotoUrl = null;
      }

      // Determine final user_id: prefer selected value, fallback to original
      final String? finalUserId =
          _selectedUserId ??
          (_originalValues != null
              ? _originalValues!['user_id'] as String?
              : null);

      if (finalUserId == null) {
        // user_id is required by the DB schema; notify user and abort
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Owner (user) is required. Please select one.'),
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final updated = {
        'status': _status,
        'user_id': finalUserId,
        'name': _nameController.text.trim(),
        'borrower_name': _borrowerController.text.trim().isEmpty
            ? null
            : _borrowerController.text.trim(),
        'borrower_contact_id': _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        'borrow_date': _borrowDate?.toIso8601String(),
        'due_date': _dueDate?.toIso8601String(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'photo_url': newPhotoUrl,
      };

      // perform update
      final updateRes = await _supabase
          .from(StorageKeys.itemsTable)
          .update(updated)
          .eq('id', widget.itemId)
          .select();
      debugPrint('EditItem: updateRes=$updateRes');

      // If we uploaded a new photo, attempt to delete previous existing photo to avoid orphans
      if (_pickedImage != null && _existingPhotoUrl != null) {
        final path = _extractStoragePath(_existingPhotoUrl!);
        if (path != null && path.isNotEmpty) {
          try {
            await _supabase.storage.from(StorageKeys.imagesBucket).remove([
              path,
            ]);
          } catch (e) {
            debugPrint('EditItem: cleanup old photo failed: $e');
          }
        }
      }

      // create audit log RPC with old and new
      try {
        await _supabase.rpc(
          'admin_create_audit_log',
          params: {
            'p_action_type': 'UPDATE',
            'p_table_name': 'items',
            'p_record_id': widget.itemId,
            'p_old_values': jsonEncode(_originalValues ?? {}),
            'p_new_values': jsonEncode(updated),
            'p_metadata': jsonEncode({'updated_via': 'admin_ui'}),
          },
        );
      } catch (e) {
        debugPrint('EditItem: audit RPC failed $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item updated')));
        Navigator.pushReplacementNamed(context, '/admin/items');
      }
    } catch (e) {
      debugPrint('EditItem: submit failed $e');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/items/${widget.itemId}/edit',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Edit Item',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                            // Owner selector
                            _loadingUsers
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Owner'),
                                      const SizedBox(height: 8),
                                      Autocomplete<String>(
                                        optionsBuilder:
                                            (
                                              TextEditingValue textEditingValue,
                                            ) {
                                              if (textEditingValue.text == '') {
                                                return _users
                                                    .map((u) => _userDisplay(u))
                                                    .take(10)
                                                    .toList();
                                              }
                                              return _users
                                                  .map((u) => _userDisplay(u))
                                                  .where(
                                                    (option) => option
                                                        .toLowerCase()
                                                        .contains(
                                                          textEditingValue.text
                                                              .toLowerCase(),
                                                        ),
                                                  )
                                                  .take(10)
                                                  .toList();
                                            },
                                        displayStringForOption: (option) =>
                                            option,
                                        fieldViewBuilder:
                                            (
                                              context,
                                              controller,
                                              focusNode,
                                              onFieldSubmitted,
                                            ) {
                                              if (_selectedUserId != null &&
                                                  controller.text.isEmpty) {
                                                final current = _users
                                                    .firstWhere(
                                                      (u) =>
                                                          u['id'] ==
                                                          _selectedUserId,
                                                      orElse: () =>
                                                          <String, dynamic>{},
                                                    );
                                                if (current.isNotEmpty) {
                                                  controller.text =
                                                      _userDisplay(current);
                                                } else if (_ownerInitialDisplay !=
                                                        null &&
                                                    _ownerInitialDisplay!
                                                        .isNotEmpty) {
                                                  controller.text =
                                                      _ownerInitialDisplay!;
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
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                            const SizedBox(height: 12),
                            // Status selector
                            DropdownButtonFormField<String>(
                              // Items table only allows 'borrowed' or 'returned'
                              value:
                                  ([
                                    AppConstants.statusBorrowed,
                                    AppConstants.statusReturned,
                                  ].contains(_status)
                                  ? _status
                                  : AppConstants.statusBorrowed),
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items:
                                  [
                                        AppConstants.statusBorrowed,
                                        AppConstants.statusReturned,
                                      ]
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) => setState(() => _status = v),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Please select a status'
                                  : null,
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
                            if (_existingPhotoUrl != null &&
                                _pickedImage == null)
                              CheckboxListTile(
                                value: _removePhoto,
                                onChanged: (v) =>
                                    setState(() => _removePhoto = v ?? false),
                                title: const Text('Remove existing photo'),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _borrowDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null)
                                        setState(() => _borrowDate = picked);
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
                                      if (picked != null)
                                        setState(() => _dueDate = picked);
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
                                  )
                                else if (_existingPhotoUrl != null)
                                  Expanded(
                                    child: Text(
                                      'Existing photo: ${_existingPhotoUrl!.split('/').last}',
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
                                    : const Text('Save changes'),
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
