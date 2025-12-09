import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/admin_service.dart';

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

class _FakeTable {
  final List<Map<String, dynamic>> result;
  _FakeTable(this.result);
  _FakeSelection select(String cols) => _FakeSelection(result);
}

class _FakeSelection {
  final List<Map<String, dynamic>> result;
  _FakeSelection(this.result);
  Future<dynamic> eq(String k, dynamic v) async {
    return result.where((r) => r[k] == v).toList();
  }

  Future<dynamic> ilike(String k, String v) async {
    final needle = v.replaceAll('%', '');
    return result
        .where((r) => (r[k] as String?)?.contains(needle) ?? false)
        .toList();
  }
}

class _FakeClient {
  final List<Map<String, dynamic>> itemsResult;
  final _FakeStorageBucket bucket;
  _FakeClient(this.itemsResult, this.bucket);
  _FakeTable from(String table) => _FakeTable(itemsResult);
  _FakeStorage get storage => _FakeStorage(bucket);
}

class TestAdminService extends AdminService {
  final List<String> updatedIds = [];
  final List<String> deletedPaths = [];
  TestAdminService(client, rpc) : super(client, rpc, null);

  @override
  Future<bool> deleteStorageObject(String path, {String? bucketId}) async {
    deletedPaths.add(path);
    return true;
  }

  @override
  Future<Map<String, dynamic>> updateItem(
    String itemId,
    Map<String, dynamic> itemData,
  ) async {
    updatedIds.add(itemId);
    return {'id': itemId, ...itemData};
  }
}

void main() {
  test(
    'deleteStorageObjectAndClearItems updates related items via updateItem',
    () async {
      final path = 'user1/photo1.jpg';
      final items = [
        {'id': 'item-1', 'photo_url': path},
        {'id': 'item-2', 'photo_url': 'prefix/user1/photo1.jpg'},
      ];

      final bucket = _FakeStorageBucket();
      final client = _FakeClient(items, bucket);

      var auditCalls = 0;
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        if (name == 'admin_create_audit_log') {
          auditCalls++;
          return [
            {'ok': true},
          ];
        }
        return [];
      }

      final svc = TestAdminService(client as dynamic, fakeRpc);
      final ok = await svc.deleteStorageObjectAndClearItems(
        path,
        bucketId: null,
        clearRelated: true,
      );
      expect(ok, isTrue);
      expect(svc.deletedPaths.contains(path), true);
      expect(svc.updatedIds.length, 2);
      expect(auditCalls, 1);
    },
  );
}
