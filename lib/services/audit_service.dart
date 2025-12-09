import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'retry_helper.dart';
import 'service_exception.dart';

/// AuditService: small wrapper for audit-related RPCs and queries.
class AuditService {
  final dynamic _supabase;
  final Future<dynamic> Function(String name, {Map<String, dynamic>? params})?
  _rpcInvokerOverride;

  AuditService([dynamic client, this._rpcInvokerOverride]) : _supabase = client;

  dynamic get _client => _supabase ?? Supabase.instance.client;

  Future<dynamic> _callRpc(String name, {Map<String, dynamic>? params}) {
    if (_rpcInvokerOverride != null)
      return _rpcInvokerOverride(name, params: params);
    return _client.rpc(name, params: params);
  }

  /// Create an audit log record using `admin_create_audit_log` RPC.
  /// Returns the created audit log row (Map) or throws ServiceException.
  Future<Map<String, dynamic>> createAuditLog({
    required String actionType,
    required String tableName,
    String? recordId,
    String? oldValues,
    String? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final mergedMeta = Map<String, dynamic>.from(metadata ?? {})
        ..addAll({
          'created_via': 'audit_service',
          'client_time': DateTime.now().toIso8601String(),
        });

      final res = await retry(
        () => _callRpc(
          'admin_create_audit_log',
          params: {
            'p_action_type': actionType,
            'p_table_name': tableName,
            'p_record_id': recordId,
            'p_old_values': oldValues,
            'p_new_values': newValues,
            'p_metadata': jsonEncode(mergedMeta),
          },
        ),
      );

      if (res is List && res.isNotEmpty) {
        return (res.first as Map).cast<String, dynamic>();
      }

      if (res is Map) return res.cast<String, dynamic>();

      throw ServiceException('Unexpected response from audit log RPC');
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  /// Get audit logs with optional filters and pagination. Returns list of maps.
  Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 50,
    int offset = 0,
    String? adminUserId,
    String? actionType,
    String? tableName,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final res = await _callRpc(
        'admin_get_audit_logs',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_user_id': adminUserId,
          'p_action_type': actionType,
          'p_table_name': tableName,
          'p_date_from': dateFrom?.toIso8601String(),
          'p_date_to': dateTo?.toIso8601String(),
        },
      );

      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ServiceException(extractErrorMessage(e), cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> getUserAuditLogs(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await getAuditLogs(
      limit: limit,
      offset: offset,
      adminUserId: userId,
    );
  }

  Future<List<Map<String, dynamic>>> getTableAuditLogs(
    String tableName, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await getAuditLogs(
      limit: limit,
      offset: offset,
      tableName: tableName,
    );
  }
}

// Singleton convenience
final AuditService auditService = AuditService();
