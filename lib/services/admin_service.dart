import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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

  /// Get top active users by activity or items (admin_get_top_users)
  Future<List<Map<String, dynamic>>> getTopActiveUsers({int limit = 10}) async {
    try {
      final res = await _callRpc(
        'admin_get_top_users',
        params: {'p_limit': limit},
      );
      if (res is List) {
        return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return <Map<String, dynamic>>[];
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
          // Migration/SQL expects p_user_filter (UUID) — map ownerId => p_user_filter
          'p_user_filter': ownerId,
          'p_search': search,
        },
      );

      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get aggregated item statistics using RPC admin_get_item_statistics() if available.
  Future<Map<String, dynamic>?> getItemStatistics() async {
    try {
      final res = await _callRpc('admin_get_item_statistics');
      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get most borrowed items. Attempts to call RPC admin_get_top_items; if not
  /// available, fall back to fetching items and computing counts client-side.
  Future<List<Map<String, dynamic>>> getMostBorrowedItems({
    int limit = 10,
  }) async {
    try {
      // Try known RPC first
      final rpcName = 'admin_get_top_items';
      try {
        final res = await _callRpc(rpcName, params: {'p_limit': limit});
        if (res is List) {
          return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
        }
      } catch (_) {
        // Fall back below
      }

      // Fallback: retrieve items and count by name or id
      final items = await getAllItems(limit: 1000, offset: 0);
      final Map<String, Map<String, dynamic>> counts = {};
      for (final it in items) {
        final key = (it['name'] ?? it['id'] ?? 'unknown').toString();
        final existing = counts[key];
        if (existing == null) {
          counts[key] = {
            'key': key,
            'name': it['name'] ?? key,
            'count': 1,
            'sample_item': it,
          };
        } else {
          existing['count'] = (existing['count'] as int) + 1;
        }
      }
      final sorted = counts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return sorted.take(limit).map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get users with most overdue items, using admin_get_top_users (which includes overdue_items)
  /// and sorting by overdue_items descending, or fall back to computation.
  Future<List<Map<String, dynamic>>> getUsersWithMostOverdue({
    int limit = 10,
  }) async {
    try {
      // Try top users function as it includes overdue counts
      final res = await _callRpc(
        'admin_get_top_users',
        params: {'p_limit': limit * 2},
      );
      if (res is List) {
        final rows = res
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        rows.sort(
          (a, b) => ((b['overdue_items'] ?? 0) as int).compareTo(
            (a['overdue_items'] ?? 0) as int,
          ),
        );
        return rows.take(limit).toList();
      }

      // fallback: aggregate items to compute overdue counts per user
      final items = await getAllItems(limit: 1000, offset: 0);
      final Map<String, Map<String, dynamic>> map = {};
      for (final it in items) {
        final owner = (it['user_id'] ?? it['owner_id'] ?? 'unknown').toString();
        final overdue =
            (it['status'] == 'borrowed' &&
                it['return_date'] != null &&
                DateTime.tryParse(
                      it['return_date']?.toString() ?? '',
                    )?.isBefore(DateTime.now()) ==
                    true)
            ? 1
            : 0;
        final existing = map[owner];
        if (existing == null) {
          map[owner] = {'user_id': owner, 'overdue_items': overdue};
        } else {
          existing['overdue_items'] =
              (existing['overdue_items'] as int) + overdue;
        }
      }
      final list = map.values.toList();
      list.sort(
        (a, b) => ((b['overdue_items'] ?? 0) as int).compareTo(
          (a['overdue_items'] ?? 0) as int,
        ),
      );
      return list.take(limit).map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Item growth per day for given number of days. Attempts to call RPC
  /// admin_get_item_growth, otherwise computes counts based on recent items.
  Future<List<Map<String, dynamic>>> getItemGrowth({int days = 30}) async {
    try {
      // Try RPC admin_get_item_growth first
      try {
        final res = await _callRpc(
          'admin_get_item_growth',
          params: {'p_days': days},
        );
        if (res is List) {
          return res.cast<Map<String, dynamic>>();
        }
      } catch (_) {}

      // Fallback: compute locally by fetching limited items and counting by date
      final items = await getAllItems(limit: 5000, offset: 0);
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days - 1));
      final counts = <String, int>{};
      for (int i = 0; i < days; i++) {
        final d = start.add(Duration(days: i));
        counts[d.toIso8601String().substring(0, 10)] = 0;
      }
      for (final it in items) {
        final createdStr = it['created_at']?.toString();
        if (createdStr == null) continue;
        final created = DateTime.tryParse(createdStr);
        if (created == null) continue;
        final key = created.toIso8601String().substring(0, 10);
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
      return counts.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList();
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
      developer.log(
        'AdminService.deleteStorageObject called path=$path bucket=$bucket',
      );
      print(
        'AdminService.deleteStorageObject called path=$path bucket=$bucket',
      );
      // Normalize path if a full URL was provided (extract object path)
      String objectPath = path;
      try {
        if (path.contains('/storage/v1/object/')) {
          final parts = path.split('/storage/v1/object/');
          if (parts.length > 1) {
            final afterObject = parts[1];
            final pathParts = afterObject.split('/');
            int bucketIndex = -1;
            for (int i = 0; i < pathParts.length; i++) {
              if (pathParts[i] == bucket) {
                bucketIndex = i;
                break;
              }
            }
            if (bucketIndex >= 0 && bucketIndex + 1 < pathParts.length) {
              objectPath = pathParts.sublist(bucketIndex + 1).join('/');
            }
          }
        }
      } catch (_) {
        // ignore normalization failure and proceed with provided path
      }
      // Attempt remove; track tried paths and attempt alternate forms if needed
      final triedPaths = <String>[];
      Future<void> attemptRemove(String p) async {
        if (p.isEmpty) return;
        triedPaths.add(p);
        developer.log('AdminService.remove attempt: $p');
        final res = await retry(() async {
          return await _client.storage.from(bucket).remove([p]);
        }, attempts: 2);
        developer.log('AdminService.remove result for $p: $res');
        print('AdminService: remove result for $p -> $res');
        // If the storage API returns an error map, throw
        try {
          if (res is Map && res.containsKey('error')) {
            throw Exception(res['error']);
          }
        } catch (_) {}
      }

      // Initial attempt — preserve error semantics so storage remove failure surfaces
      await attemptRemove(objectPath);

      // Verify that the file no longer appears in storage listing (best-effort)
      try {
        final resCheck = await _callRpc(
          'admin_list_storage_files',
          params: {
            'p_bucket_id': bucket,
            'p_limit': 10,
            'p_offset': 0,
            'p_search': objectPath,
          },
        );
        var _count = 0;
        if (resCheck is List) _count = resCheck.length;
        developer.log(
          'AdminService.deleteStorageObject listing check count=$_count',
        );
        print('AdminService.deleteStorageObject listing check count=$_count');
        if (resCheck is List && resCheck.isNotEmpty) {
          // If there's any file whose name equals or ends with the objectPath, consider deletion failed
          for (final r in resCheck) {
            final n = (r as Map)['name']?.toString() ?? '';
            if (n == objectPath || n.endsWith(objectPath)) {
              developer.log(
                'AdminService.deleteStorageObject: listing still contains object: $n',
              );
              print(
                'AdminService.deleteStorageObject: listing still contains object: $n',
              );
              final foundNames = <String>[];
              for (final rr in resCheck) {
                foundNames.add((rr as Map)['name']?.toString() ?? '');
              }
              // Try removing the exact listed name if it differs from the requested objectPath
              if (n != objectPath && !triedPaths.contains(n)) {
                try {
                  developer.log(
                    'AdminService.deleteStorageObject: trying remove with full listed name: $n',
                  );
                  print(
                    'AdminService.deleteStorageObject: trying remove with full listed name: $n',
                  );
                  await attemptRemove(n);
                  // If it succeeded, re-check through alternate logic below
                } catch (e) {
                  developer.log(
                    'AdminService.deleteStorageObject: failed to remove by listed name $n: $e',
                  );
                  print(
                    'AdminService.deleteStorageObject: failed to remove by listed name $n: $e',
                  );
                }
              }
              // Prepare alternate path attempts
              final alternates = <String>[];
              // Strip query params
              if (objectPath.contains('?'))
                alternates.add(objectPath.split('?')[0]);
              // Try toggling "public/" prefix
              if (!objectPath.startsWith('public/'))
                alternates.add('public/$objectPath');
              if (objectPath.startsWith('public/'))
                alternates.add(objectPath.replaceFirst('public/', ''));
              // If objectPath contains bucket, try removing bucket prefix
              if (objectPath.startsWith('$bucket/'))
                alternates.add(objectPath.replaceFirst('$bucket/', ''));
              alternates.removeWhere(
                (a) => a.isEmpty || triedPaths.contains(a),
              );
              var removed = false;
              for (final alt in alternates) {
                try {
                  developer.log(
                    'AdminService.deleteStorageObject: trying alternate remove for $alt',
                  );
                  print(
                    'AdminService.deleteStorageObject: trying alternate remove for $alt',
                  );
                  await attemptRemove(alt);
                  removed = true;
                  break;
                } catch (e) {
                  developer.log(
                    'AdminService.deleteStorageObject: alternate remove failed for $alt -> $e',
                  );
                  print(
                    'AdminService.deleteStorageObject: alternate remove failed for $alt -> $e',
                  );
                }
              }
              if (removed) {
                developer.log(
                  'AdminService.deleteStorageObject: alternate removal attempt succeeded, re-checking listing',
                );
                final newResCheck = await _callRpc(
                  'admin_list_storage_files',
                  params: {
                    'p_bucket_id': bucket,
                    'p_limit': 10,
                    'p_offset': 0,
                    'p_search': objectPath,
                  },
                );
                var stillFound = false;
                if (newResCheck is List && newResCheck.isNotEmpty) {
                  for (final r2 in newResCheck) {
                    final n2 = (r2 as Map)['name']?.toString() ?? '';
                    if (n2 == objectPath || n2.endsWith(objectPath)) {
                      stillFound = true;
                      break;
                    }
                  }
                }
                // Try to remove all found names as a last resort
                for (final fn in foundNames) {
                  if (triedPaths.contains(fn)) continue;
                  try {
                    developer.log(
                      'AdminService.deleteStorageObject: trying remove with listed name: $fn',
                    );
                    print(
                      'AdminService.deleteStorageObject: trying remove with listed name: $fn',
                    );
                    await attemptRemove(fn);
                  } catch (err) {
                    developer.log(
                      'AdminService.deleteStorageObject: failed to remove by listed name $fn: $err',
                    );
                    print(
                      'AdminService.deleteStorageObject: failed to remove by listed name $fn: $err',
                    );
                  }
                }
                if (!stillFound) {
                  // success — object no longer appears in listing
                  developer.log(
                    'AdminService.deleteStorageObject: object $objectPath no longer found after alternate remove',
                  );
                  continue;
                }
                // If still found, let the loop continue to eventually throw
                developer.log(
                  'AdminService.deleteStorageObject: object $objectPath still present after alternate remove',
                );
              }
              throw Exception(
                'Deletion unsuccessful: object still present in storage listing; found: ${foundNames.join(', ')}',
              );
            }
          }
        }
      } catch (_) {
        // We don't want to fail silently, but for now treat as potential failure
        // (will be surfaced by the catch block below)
        rethrow;
      }
      // Create an audit log entry for storage deletion (best-effort)
      try {
        await retry(
          () => _callRpc(
            'admin_create_audit_log',
            params: {
              'p_action_type': 'DELETE',
              'p_table_name': 'storage.objects',
              'p_record_id': objectPath,
              'p_old_values': null,
              'p_new_values': null,
              'p_metadata': jsonEncode({'bucket': bucket, 'path': objectPath}),
            },
          ),
          attempts: 2,
        );
      } catch (_) {
        // non-fatal — we don't want audit failures to block deletion
      }

      // Try to unlink references from items.photo_url - handle exact and like matches separately
      developer.log(
        'AdminService.deleteStorageObject: attempting to unlink item references for $objectPath',
      );
      try {
        final pk = StorageKeys.columnPhotoUrl;
        int updatedCount = 0;

        // Exact matches
        try {
          final resEq = await _client
              .from(StorageKeys.itemsTable)
              .update({pk: null})
              .eq('photo_url', objectPath)
              .select();
          if (resEq is List) updatedCount += resEq.length;
        } catch (_) {}

        // Partial matches (photo_url contains object path)
        try {
          final resLike = await _client
              .from(StorageKeys.itemsTable)
              .update({pk: null})
              .like('photo_url', '%$objectPath')
              .select();
          if (resLike is List) updatedCount += resLike.length;
        } catch (_) {}

        // Create audit log for the unlink operation if any rows were updated
        if (updatedCount > 0) {
          developer.log(
            'AdminService.deleteStorageObject: unlinked $updatedCount item rows referring to $objectPath',
          );
          try {
            await retry(
              () => _callRpc(
                'admin_create_audit_log',
                params: {
                  'p_action_type': 'UPDATE',
                  'p_table_name': StorageKeys.itemsTable,
                  'p_record_id': objectPath,
                  'p_old_values': null,
                  'p_new_values': jsonEncode({'photo_url': null}),
                  'p_metadata': jsonEncode({
                    'bucket': bucket,
                    'path': objectPath,
                    'action': 'unlink',
                    'rows': updatedCount,
                  }),
                },
              ),
              attempts: 2,
            );
          } catch (_) {}
        }
      } catch (_) {}

      return true;
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Delete multiple storage objects and return a summary map like:
  /// { 'deleted': [path...], 'failed': [{path: '...', error: '...'}] }
  Future<Map<String, dynamic>> deleteStorageObjects(
    List<String> paths, {
    String? bucketId,
  }) async {
    final deleted = <String>[];
    final failed = <Map<String, String>>[];
    for (final p in paths) {
      try {
        final ok = await deleteStorageObject(p, bucketId: bucketId);
        if (ok) {
          deleted.add(p);
        } else {
          failed.add({'path': p, 'error': 'Unknown failure'});
        }
      } catch (e) {
        failed.add({'path': p, 'error': e.toString()});
      }
    }
    return {'deleted': deleted, 'failed': failed};
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
