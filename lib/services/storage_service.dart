import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/storage_keys.dart';
import 'retry_helper.dart';
import 'service_exception.dart';

/// StorageService: wrapper around storage-related admin RPCs
class StorageService {
  final dynamic _supabase;
  final Future<dynamic> Function(String name, {Map<String, dynamic>? params})?
  _rpcInvokerOverride;

  StorageService([dynamic client, this._rpcInvokerOverride])
    : _supabase = client;

  dynamic get _client => _supabase ?? Supabase.instance.client;

  Future<dynamic> _callRpc(String name, {Map<String, dynamic>? params}) {
    if (_rpcInvokerOverride != null) {
      return _rpcInvokerOverride(name, params: params);
    }
    return _client.rpc(name, params: params);
  }

  static final StorageService instance = StorageService();

  /// Retrieves storage usage statistics via `admin_get_storage_stats` RPC.
  /// Returns a parsed `Map<String, dynamic>` with keys such as
  /// total_files, total_size_bytes, orphaned_count, items_with_photos.
  Future<Map<String, dynamic>> getStorageStats({String? bucketId}) async {
    try {
      final effectiveBucket = bucketId ?? StorageKeys.imagesBucket;
      final res = await _callRpc(
        'admin_get_storage_stats',
        params: {'p_bucket_id': effectiveBucket},
      );
      if (res is List && res.isNotEmpty) {
        final rawMap = (res.first as Map).cast<String, dynamic>();
        // Debug logging removed; keep production logging only (warning/errors handled elsewhere)
        final normalized = _normalizeStats(rawMap);
        // Debug logging removed
        return normalized;
      }
      if (res is Map) {
        // Debug logging removed
        final normalized = _normalizeStats(Map<String, dynamic>.from(res));
        // Debug logging removed
        return normalized;
      }
      return <String, dynamic>{};
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get storage usage grouped by user. Returns a list of maps with keys:
  ///  - user_id
  ///  - user_email
  ///  - total_size_bytes
  ///  - file_count
  Future<List<Map<String, dynamic>>> getStorageByUser({
    String? bucketId,
    int limit = 10,
  }) async {
    try {
      final effectiveBucket = bucketId ?? StorageKeys.imagesBucket;
      final res = await _callRpc(
        'admin_get_storage_by_user',
        params: {'p_bucket_id': effectiveBucket, 'p_limit': limit},
      );
      if (res is List) {
        return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get file type distribution for bucket. Returns list of maps:
  ///  - extension
  ///  - file_count
  ///  - total_size_bytes
  Future<List<Map<String, dynamic>>> getFileTypeDistribution({
    String? bucketId,
  }) async {
    try {
      final effectiveBucket = bucketId ?? StorageKeys.imagesBucket;
      final res = await _callRpc(
        'admin_get_storage_file_type_distribution',
        params: {'p_bucket_id': effectiveBucket},
      );
      if (res is List) {
        return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// List storage files in a bucket (admin RPC wrapper). Supports pagination
  /// and optional search by filename/path.
  Future<List<Map<String, dynamic>>> listFiles({
    String? bucketId,
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    try {
      final effectiveBucket = bucketId ?? StorageKeys.imagesBucket;
      final res = await _callRpc(
        'admin_list_storage_files',
        params: {
          'p_bucket_id': effectiveBucket,
          'p_limit': limit,
          'p_offset': offset,
          'p_search': search,
        },
      );
      if (res is List) {
        return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Returns a list of orphaned storage files (not referenced by items.photo_url)
  /// Supports optional pagination.
  Future<List<Map<String, dynamic>>> listOrphanedFiles({
    String? bucketId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final effectiveBucket = bucketId ?? StorageKeys.imagesBucket;
      final res = await _callRpc(
        'admin_list_orphaned_storage_files',
        params: {
          'p_bucket_id': effectiveBucket,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (res is List) {
        return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Map<String, dynamic> _normalizeStats(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);

    num? toNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      final s = v.toString();
      // Try int first, then double
      final i = int.tryParse(s);
      if (i != null) return i;
      final d = double.tryParse(s);
      if (d != null) return d;
      return 0;
    }

    // Normalize aliases first so we convert them into canonical keys
    if (!m.containsKey('orphaned_files') && m.containsKey('orphaned_count')) {
      m['orphaned_files'] = m['orphaned_count'];
    }
    if (!m.containsKey('total_size_bytes') && m.containsKey('total_size')) {
      m['total_size_bytes'] = m['total_size'];
    }
    m['total_files'] = toNum(m['total_files'])?.toInt();
    m['total_size_bytes'] = toNum(m['total_size_bytes'])?.toInt();
    m['orphaned_files'] = toNum(m['orphaned_files'])?.toInt();
    m['items_with_photos'] = toNum(m['items_with_photos'])?.toInt();
    // Support alternate 'total_size' key (some endpoints used a different name)
    if (!m.containsKey('total_size_bytes') && m.containsKey('total_size')) {
      m['total_size_bytes'] = m['total_size'];
    }
    m['total_size_bytes'] = toNum(m['total_size_bytes'])?.toInt();
    m['total_size_mb'] = toNum(m['total_size_mb']);
    m['avg_file_size_kb'] = toNum(m['avg_file_size_kb']);
    m['largest_file_size_mb'] = toNum(m['largest_file_size_mb']);
    m['smallest_file_size_kb'] = toNum(m['smallest_file_size_kb']);

    return m;
  }
}
