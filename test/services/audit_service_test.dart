import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/audit_service.dart';
import 'package:pinjam_in/services/service_exception.dart';

void main() {
  test('createAuditLog calls RPC and returns map', () async {
    var called = false;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_create_audit_log');
      called = true;
      // Validate metadata includes created_via and client_time
      final meta = params?['p_metadata'] as String?;
      expect(meta, isNotNull);
      expect(meta!.contains('created_via'), isTrue);
      expect(meta.contains('client_time'), isTrue);
      return [
        {'id': 'a1', 'action_type': params?['p_action_type']},
      ];
    }

    final svc = AuditService(null, fakeRpc);
    final res = await svc.createAuditLog(
      actionType: 'CREATE',
      tableName: 'items',
      recordId: 'i1',
      newValues: '{"name": "X"}',
    );
    expect(called, isTrue);
    expect(res['id'], 'a1');
    expect(res['action_type'], 'CREATE');
  });

  test('getAuditLogs returns parsed list', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_audit_logs');
      return [
        {'id': 'a1'},
        {'id': 'a2'},
      ];
    }

    final svc = AuditService(null, fakeRpc);
    final list = await svc.getAuditLogs(limit: 2);
    expect(list, hasLength(2));
  });

  test('getUserAuditLogs filters on user', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_audit_logs');
      expect(params?['p_user_id'], 'u1');
      return [
        {'id': 'u1-a1'},
      ];
    }

    final svc = AuditService(null, fakeRpc);
    final list = await svc.getUserAuditLogs('u1');
    expect(list, hasLength(1));
  });

  test('getTableAuditLogs filters on table', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_audit_logs');
      expect(params?['p_table_name'], 'items');
      return [
        {'id': 'i1-a1'},
      ];
    }

    final svc = AuditService(null, fakeRpc);
    final list = await svc.getTableAuditLogs('items');
    expect(list, hasLength(1));
  });

  test('RPC errors are wrapped in ServiceException', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      throw Exception('boom');
    }

    final svc = AuditService(null, fakeRpc);
    expect(() => svc.getAuditLogs(), throwsA(isA<ServiceException>()));
  });
}
