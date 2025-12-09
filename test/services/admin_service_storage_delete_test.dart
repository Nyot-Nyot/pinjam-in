import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/admin_service.dart';
// no extra imports required

class _FakeSelection {
  final List<Map<String, dynamic>> result;
  _FakeSelection(this.result);
  Future<dynamic> eq(String k, dynamic v) async {
    // Return rows where k equals v
    return result.where((r) => r[k] == v).toList();
  }

  Future<dynamic> ilike(String k, String v) async {
    final needle = v.replaceAll('%', '');
    return result
        .where((r) => (r[k] as String?)?.contains(needle) ?? false)
        .toList();
  }

  Future<dynamic> update(Map m) async {
    // Return a single updated record for simplicity
    return [m];
  }
}

class _FakeTable {
  final List<Map<String, dynamic>> result;
  _FakeTable(this.result);
  _FakeSelection select(String cols) => _FakeSelection(result);
  // update will be used with chained .update(...).eq('id', id)
  Future<dynamic> update(Map m) async => [m];
}

class _FakeStorageBucket {
  final List<String> removed = [];
  _FakeStorageBucket();
  Future<void> remove(List<String> paths) async {
    removed.addAll(paths);
    return;
  }
}

class _FakeStorage {
  final _FakeStorageBucket bucket;
  _FakeStorage(this.bucket);
  _FakeStorageBucket from(String bucket) => this.bucket;
}

class _FakeClient {
  final List<Map<String, dynamic>> itemsResult;
  final _FakeStorageBucket bucket;
  int updatedCount = 0;
  _FakeClient(this.itemsResult, this.bucket);
  _FakeTable from(String table) => _FakeTable(itemsResult);
  _FakeStorage get storage => _FakeStorage(bucket);
}

void main() {
  test(
    'deleteStorageObjectAndClearItems clears related items and creates audit log',
    () async {
      final path = 'images/user1/photo1.jpg';
      // Two items referencing the path (one exact match and one contains)
      final items = [
        {'id': 'item-111', 'photo_url': path},
        {'id': 'item-222', 'photo_url': 'prefix/$path'},
      ];

      // Fake storage bucket that will 'remove' the path
      final bucket = _FakeStorageBucket();
      final fakeClient = _FakeClient(items, bucket);

      var auditCalls = 0;
      final capturedAudit = <Map<String, dynamic>>[];
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        if (name == 'admin_create_audit_log') {
          auditCalls++;
          capturedAudit.add(params ?? {});
          return [
            {'ok': true},
          ];
        }
        // For any other RPCs, return basic values (e.g., getItemDetails)
        if (name == 'admin_get_item_details') {
          return [
            {'id': params?['p_item_id'], 'photo_url': path},
          ];
        }
        return [];
      }

      final svc = AdminService(fakeClient as dynamic, fakeRpc, null);
      final ok = await svc.deleteStorageObjectAndClearItems(
        path,
        bucketId: null,
        clearRelated: true,
      );
      expect(ok, isTrue);
      expect(bucket.removed.contains(path), true);
      // Audit log should be called once for the deletion
      expect(auditCalls, 1);
      expect(capturedAudit.isNotEmpty, true);
      // Ensure the metadata contains the key cleared_item_ids
      final md = capturedAudit.first['p_metadata'] as String?;
      expect(md, isNotNull);
      expect(md!.contains('cleared_item_ids'), true);
    },
  );
}
