import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/storage_keys.dart';
import '../di/service_locator.dart';
import 'retry_helper.dart';
import 'service_exception.dart';

/// Lightweight AdminService: thin wrappers around Supabase RPCs used by
/// admin screens/providers. Methods return parsed dynamic results and
/// perform basic error handling. We'll expand functionality and add
/// tests in subsequent subtasks.
class AdminService {
  final dynamic _supabase;
  final Future<dynamic> Function(String name, {Map<String, dynamic>? params})?
  _rpcInvokerOverride;
  final Future<dynamic> Function(String fnName, {dynamic body})?
  _functionsInvokerOverride;

  AdminService([
    dynamic client,
    this._rpcInvokerOverride,
    this._functionsInvokerOverride,
  ]) : _supabase = client;

  dynamic get _client => _supabase ?? Supabase.instance.client;

  Future<dynamic> _callRpc(String name, {Map<String, dynamic>? params}) {
    if (_rpcInvokerOverride != null) {
      return _rpcInvokerOverride(name, params: params);
    }
    return _client.rpc(name, params: params);
  }

  Future<dynamic> _callFunction(String fnName, {dynamic body}) {
    if (_functionsInvokerOverride != null) {
      return _functionsInvokerOverride(fnName, body: body);
    }
    return _client.functions.invoke(fnName, body: body);
  }

  /// Singleton instance convenience
  static final AdminService instance = AdminService();

  /// Get dashboard statistics by calling the `admin_get_dashboard_stats` RPC.
  /// Returns the first row as `Map<String, dynamic>` or null if not present.
  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final res = await _callRpc('admin_get_dashboard_stats');

      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get all users with optional filters/pagination. Returns the raw RPC
  /// response (usually a `List<Map<String, dynamic>>` of records). We'll refine the signature later.
  Future<List<Map<String, dynamic>>> getAllUsers({
    int limit = 50,
    int offset = 0,
    String? role,
    String? status,
    String? search,
  }) async {
    try {
      final res = await _callRpc(
        'admin_get_all_users',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_role': role,
          'p_status': status,
          'p_search': search,
        },
      );

      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final res = await _callRpc(
        'admin_get_user_details',
        params: {'p_user_id': userId},
      );
      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Create / update / delete user helpers will be implemented in later
  /// subtasks. For now provide simple stubs that call corresponding RPCs
  /// or Supabase Auth where applicable.
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    try {
      // Use the server-side edge function to create users with service role
      final res = await _callFunction('admin_create_user', body: userData);

      if (res.status != 200) {
        final err = res.data?['error'] ?? 'Failed to create user';
        throw Exception(err);
      }

      return (res.data as Map).cast<String, dynamic>();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Prefer using dedicated admin RPCs when possible to ensure audit logs
      if (userData.containsKey('full_name')) {
        final res = await _callRpc(
          'admin_update_user_profile',
          params: {'p_user_id': userId, 'p_full_name': userData['full_name']},
        );

        if (res is List && res.isNotEmpty) {
          return (res.first as Map).cast<String, dynamic>();
        }
        throw Exception('Failed to update profile');
      }

      if (userData.containsKey('role')) {
        final res = await _callRpc(
          'admin_update_user_role',
          params: {'p_user_id': userId, 'p_new_role': userData['role']},
        );

        if (res is List && res.isNotEmpty) {
          return (res.first as Map).cast<String, dynamic>();
        }
        throw Exception('Failed to update role');
      }

      if (userData.containsKey('status')) {
        final res = await _callRpc(
          'admin_update_user_status',
          params: {
            'p_user_id': userId,
            'p_new_status': userData['status'],
            'p_reason': userData['reason'],
          },
        );

        if (res is List && res.isNotEmpty) {
          return (res.first as Map).cast<String, dynamic>();
        }
        throw Exception('Failed to update status');
      }

      // If no known keys, perform a direct profiles update (fallback)
      final updateRes = await _client
          .from('profiles')
          .update(userData)
          .eq('id', userId);
      return {'success': true, 'updated': updateRes};
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<bool> deleteUser(String userId, {bool hardDelete = false}) async {
    try {
      final res = await _callRpc(
        'admin_delete_user',
        params: {'p_user_id': userId, 'p_hard_delete': hardDelete},
      );

      // RPC functions commonly return a row with success metadata; accept any non-empty response as success
      if (res is List) {
        return res.isNotEmpty;
      }
      return true;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> getAllItems({
    int limit = 50,
    int offset = 0,
    String? status,
    String? ownerId,
    String? search,
  }) async {
    try {
      final res = await _callRpc(
        'admin_get_all_items',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_status_filter': status,
          'p_owner_filter': ownerId,
          'p_search': search,
        },
      );

      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<Map<String, dynamic>?> getItemDetails(String itemId) async {
    try {
      final res = await _callRpc(
        'admin_get_item_details',
        params: {'p_item_id': itemId},
      );
      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<Map<String, dynamic>> createItem(
    String userId,
    Map<String, dynamic> itemData,
  ) async {
    try {
      final id = const Uuid().v4();

      String? photoUrl;
      final persistence = ServiceLocator.persistenceService;
      final localPhoto =
          itemData['localPhotoPath'] as String? ??
          itemData['photo_local_path'] as String?;

      if (localPhoto != null && localPhoto.isNotEmpty) {
        try {
          // transient uploads may fail; retry a couple times before giving up
          photoUrl = await retry(
            () => persistence.uploadImage(localPhoto, id),
            attempts: 2,
          );
        } catch (e) {
          // Image upload is optional — continue without failing creation
        }
      }

      final nowIso = DateTime.now().toIso8601String();

      final item = <String, dynamic>{
        'id': id,
        'user_id': userId,
        'name': itemData['name'] as String?,
        'borrower_name': (itemData['borrower_name'] as String?)?.trim(),
        'borrower_contact_id':
            (itemData['borrower_contact_id'] as String?)?.trim() ??
            itemData['borrower_contact'] as String?,
        'borrow_date': itemData['borrow_date'] is DateTime
            ? (itemData['borrow_date'] as DateTime).toIso8601String()
            : itemData['borrow_date'] as String?,
        'due_date': itemData['due_date'] is DateTime
            ? (itemData['due_date'] as DateTime).toIso8601String()
            : itemData['due_date'] as String?,
        'status': itemData['status'] as String? ?? 'borrowed',
        'notes': (itemData['notes'] as String?)?.trim(),
        'photo_url': photoUrl ?? itemData['photo_url'] as String?,
        'created_at': nowIso,
      };

      final insertRes = await _client
          .from(StorageKeys.itemsTable)
          .insert(item)
          .select();

      // Try to create an audit log; don't fail creation if audit RPC errors.
      try {
        // best-effort audit log; retry transient errors a couple times
        await retry(
          () => _callRpc(
            'admin_create_audit_log',
            params: {
              'p_action_type': 'CREATE',
              'p_table_name': StorageKeys.itemsTable,
              'p_record_id': id,
              'p_old_values': null,
              'p_new_values': jsonEncode(item),
              'p_metadata': jsonEncode({'created_via': 'admin_service'}),
            },
          ),
          attempts: 2,
        );
      } catch (_) {
        // non-fatal
      }

      try {
        final asList = insertRes as List;
        if (asList.isNotEmpty) {
          return (asList.first as Map).cast<String, dynamic>();
        }
      } catch (_) {}

      try {
        final asMap = insertRes as Map;
        return asMap.cast<String, dynamic>();
      } catch (_) {}

      return {'success': true, 'id': id};
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Delete a storage object from the specified bucket. Returns true on success.
  Future<bool> deleteStorageObject(String path, {String? bucketId}) async {
    try {
      final bucket = bucketId ?? StorageKeys.imagesBucket;
      await retry(() async {
        return await _client.storage.from(bucket).remove([path]);
      }, attempts: 2);
      return true;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Delete a storage object and optionally clear `photo_url` references on
  /// items that referenced it. This ensures DB rows do not point to deleted
  /// storage objects. The method also creates an audit log entry for the
  /// deletion.
  Future<bool> deleteStorageObjectAndClearItems(
    String path, {
    String? bucketId,
    bool clearRelated = true,
  }) async {
    try {
      final bucket = bucketId ?? StorageKeys.imagesBucket;
      final deleted = await deleteStorageObject(path, bucketId: bucket);

      final clearedItemIds = <String>[];
      if (deleted && clearRelated) {
        try {
          // Find items where photo_url matches the path exactly
          final exactRes = await _client
              .from(StorageKeys.itemsTable)
              .select('id')
              .eq('photo_url', path);
          final exactRows = exactRes is List
              ? exactRes
              : (exactRes is Map ? [exactRes] : <dynamic>[]);
          // Also try to match items where photo_url contains the path
          final likeRes = await _client
              .from(StorageKeys.itemsTable)
              .select('id')
              .ilike('photo_url', '%$path%');
          final likeRows = likeRes is List
              ? likeRes
              : (likeRes is Map ? [likeRes] : <dynamic>[]);

          final ids = <String>{};
          for (final r in exactRows) {
            try {
              final id = (r as Map)['id'] as String?;
              if (id != null) ids.add(id);
            } catch (_) {}
          }
          for (final r in likeRows) {
            try {
              final id = (r as Map)['id'] as String?;
              if (id != null) ids.add(id);
            } catch (_) {}
          }

          for (final id in ids) {
            try {
              // Use updateItem to ensure audit logging and validations
              await updateItem(id, {'photo_url': null});
              clearedItemIds.add(id);
            } catch (_) {}
          }
        } catch (_) {
          // Non-fatal; we don't want to fail the deletion if clearing fails
        }
      }

      // Create an audit log for the storage deletion
      try {
        await _callRpc(
          'admin_create_audit_log',
          params: {
            'p_action_type': 'DELETE',
            'p_table_name': 'storage',
            'p_record_id': path,
            'p_old_values': null,
            'p_new_values': null,
            'p_metadata': jsonEncode({
              'bucket': bucket,
              'cleared_item_ids': clearedItemIds,
            }),
          },
        );
      } catch (_) {
        // Non-fatal
      }

      return deleted;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<Map<String, dynamic>> updateItem(
    String itemId,
    Map<String, dynamic> itemData,
  ) async {
    try {
      // Load existing item for old values
      final existing = await getItemDetails(itemId);
      if (existing == null) {
        throw Exception('Item not found: $itemId');
      }

      final oldValues = Map<String, dynamic>.from(existing);

      String? photoUrl = oldValues['photo_url'] as String?;

      // Handle new photo upload if provided
      final persistence = ServiceLocator.persistenceService;
      final localPhoto =
          itemData['localPhotoPath'] as String? ??
          itemData['photo_local_path'] as String?;

      if (localPhoto != null && localPhoto.isNotEmpty) {
        try {
          final uploaded = await persistence.uploadImage(localPhoto, itemId);
          if (uploaded != null && uploaded.isNotEmpty) {
            photoUrl = uploaded;
          }
        } catch (_) {
          // If upload fails, keep existing photoUrl and continue
        }
      } else if (itemData['removePhoto'] == true) {
        // Caller requested photo removal; set to null. Actual storage
        // deletion (removing file) is left to dedicated cleanup or delete flow.
        photoUrl = null;
      }

      // Build update map with allowed fields
      final updated = <String, dynamic>{};
      void putIfPresent(String key, dynamic value) {
        if (value != null) updated[key] = value;
      }

      putIfPresent('name', (itemData['name'] as String?)?.trim());
      putIfPresent(
        'borrower_name',
        (itemData['borrower_name'] as String?)?.trim(),
      );
      putIfPresent(
        'borrower_contact_id',
        (itemData['borrower_contact_id'] as String?)?.trim() ??
            (itemData['borrower_contact'] as String?),
      );
      final bd = itemData['borrow_date'];
      if (bd != null) {
        putIfPresent('borrow_date', bd is DateTime ? bd.toIso8601String() : bd);
      }
      final dd = itemData['due_date'];
      if (dd != null) {
        putIfPresent('due_date', dd is DateTime ? dd.toIso8601String() : dd);
      }
      putIfPresent('status', itemData['status'] as String?);
      putIfPresent('notes', (itemData['notes'] as String?)?.trim());

      // Always include resolved photo_url (may be null to clear)
      if (updated.containsKey('photo_url') ||
          photoUrl != oldValues['photo_url']) {
        updated['photo_url'] = photoUrl;
      }

      if (updated.isEmpty) {
        return oldValues;
      }

      final res = await _client
          .from(StorageKeys.itemsTable)
          .update(updated)
          .eq('id', itemId)
          .select();

      // Create audit log with old/new values; non-fatal if it fails
      try {
        await retry(
          () => _callRpc(
            'admin_create_audit_log',
            params: {
              'p_action_type': 'UPDATE',
              'p_table_name': StorageKeys.itemsTable,
              'p_record_id': itemId,
              'p_old_values': jsonEncode(oldValues),
              'p_new_values': jsonEncode({...oldValues, ...updated}),
              'p_metadata': jsonEncode({'updated_via': 'admin_service'}),
            },
          ),
          attempts: 2,
        );
      } catch (_) {
        // non-fatal
      }

      try {
        final asList = res as List;
        if (asList.isNotEmpty) {
          return (asList.first as Map).cast<String, dynamic>();
        }
      } catch (_) {}

      try {
        final asMap = res as Map;
        return asMap.cast<String, dynamic>();
      } catch (_) {}

      return {'success': true, 'id': itemId};
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<bool> deleteItem(String itemId, {bool hardDelete = false}) async {
    try {
      // Optionally remove storage file if caller passes p_delete_storage flag
      final shouldDeleteStorage = hardDelete;

      // Fetch item details to know photo_url for optional storage deletion
      final existing = await getItemDetails(itemId);

      if (existing != null) {
        final photoUrl = existing['photo_url'] as String?;
        if (photoUrl != null && photoUrl.isNotEmpty && shouldDeleteStorage) {
          try {
            // Attempt to extract storage path and remove via Supabase storage API
            String? storagePath;
            if (photoUrl.contains('/storage/v1/object/')) {
              final parts = photoUrl.split('/storage/v1/object/');
              if (parts.length > 1) {
                final afterObject = parts[1];
                final pathParts = afterObject.split('/');
                // expected: [maybe 'public'|'sign', bucket, ...path]
                if (pathParts.length > 2) {
                  storagePath = pathParts.sublist(2).join('/');
                  if (storagePath.contains('?')) {
                    storagePath = storagePath.split('?')[0];
                  }
                }
              }
            }

            if (storagePath != null && storagePath.isNotEmpty) {
              try {
                await _client.storage.from(StorageKeys.imagesBucket).remove([
                  storagePath,
                ]);
              } catch (_) {
                // ignore storage deletion errors — do not fail item delete
              }
            }
          } catch (_) {}
        }
      }

      // Call admin RPC to delete item (handles audit and soft/hard semantics)
      try {
        final res = await retry(
          () => _callRpc(
            'admin_delete_item',
            params: {'p_item_id': itemId, 'p_hard_delete': hardDelete},
          ),
          attempts: 2,
        );

        try {
          final asList = res as List;
          return asList.isNotEmpty;
        } catch (_) {}
        return true;
      } catch (e) {
        throw ServiceException(extractErrorMessage(e), cause: e);
      }
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }
}
