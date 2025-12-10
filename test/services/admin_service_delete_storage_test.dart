import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/admin_service.dart';

class _FakeStorageBucket {
  Future<void> remove(List<String> paths) async {}
}

class _FakeStorage {
  _FakeStorageBucket from(String bucket) => _FakeStorageBucket();
}

class _FakeSupabaseClient {
  _FakeSupabaseClient();
  _FakeStorage get storage => _FakeStorage();
}

void main() {
  test('deleteStorageObject removes storage and creates audit log', () async {
    var auditCalls = 0;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_create_audit_log') {
        auditCalls++;
        return [
          {'ok': true},
        ];
      }
      return [];
    }

    final fakeClient = _FakeSupabaseClient();
    final svc = AdminService(fakeClient as dynamic, fakeRpc, null);

    final path = 'user1/photo1.jpg';
    final res = await svc.deleteStorageObject(path, bucketId: 'item_photos');
    expect(res, isTrue);
    expect(auditCalls, 1);
  });
}
