import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/models/loan_item.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/persistence_service.dart';

class _FakePersistence extends PersistenceService {
  final String? toReturn;
  _FakePersistence(this.toReturn);

  @override
  Future<String?> uploadImage(String localPath, String itemId) async {
    return toReturn;
  }

  // Minimal implementations for abstract members
  @override
  Future<List<LoanItem>> loadActive() async => <LoanItem>[];
  @override
  Future<List<LoanItem>> loadHistory() async => <LoanItem>[];
  @override
  Future<void> saveActive(List<LoanItem> active) async {}
  @override
  Future<void> saveHistory(List<LoanItem> history) async {}
}

class _FakeQuery {
  final dynamic _result;
  _FakeQuery(this._result);
  _FakeQuery insert(Map m) => this;
  _FakeQuery update(Map m) => this;
  _FakeQuery eq(String k, dynamic v) => this;
  Future<dynamic> select() async => _result;
}

class _FakeTable {
  final dynamic _result;
  _FakeTable(this._result);
  _FakeQuery insert(Map m) => _FakeQuery(_result);
  _FakeQuery update(Map m) => _FakeQuery(_result);
}

class _FakeStorageBucket {
  Future<void> remove(List<String> paths) async {}
}

class _FakeStorage {
  _FakeStorageBucket from(String bucket) => _FakeStorageBucket();
}

class _FakeSupabaseClient {
  final dynamic tableResult;
  _FakeSupabaseClient(this.tableResult);
  _FakeTable from(String table) => _FakeTable(tableResult);
  _FakeStorage get storage => _FakeStorage();
}

void main() {
  test('createItem uploads photo and inserts item', () async {
    final uploadedUrl = 'https://cdn.example.com/images/item-123.jpg';
    // persistence returns uploaded url
    ServiceLocator.setPersistenceService(_FakePersistence(uploadedUrl));

    // fake RPC: audit log should be called once
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

    // fake client returns the inserted item as a single-element list
    final fakeClient = _FakeSupabaseClient([
      {'id': 'item-123', 'photo_url': uploadedUrl},
    ]);

    final svc = AdminService(fakeClient as dynamic, fakeRpc, null);

    final res = await svc.createItem('user-1', {
      'name': 'Widget',
      'localPhotoPath': '/tmp/photo.jpg',
    });

    expect(res['id'], isNotNull);
    expect(res['photo_url'], uploadedUrl);
    expect(auditCalls, 1);
  });

  test('updateItem uploads new photo and updates record', () async {
    final newUrl = 'https://cdn.example.com/images/item-456-new.jpg';
    ServiceLocator.setPersistenceService(_FakePersistence(newUrl));

    // RPC handler: return existing item for getItemDetails and accept audit log
    var auditCalls = 0;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_item_details') {
        return [
          {
            'id': params?['p_item_id'],
            'photo_url': 'https://old.example/old.jpg',
          },
        ];
      }
      if (name == 'admin_create_audit_log') {
        auditCalls++;
        return [
          {'ok': true},
        ];
      }
      return [];
    }

    final fakeClient = _FakeSupabaseClient([
      {'id': 'item-456', 'photo_url': newUrl},
    ]);
    final svc = AdminService(fakeClient as dynamic, fakeRpc, null);

    final res = await svc.updateItem('item-456', {
      'localPhotoPath': '/tmp/new.jpg',
      'name': 'Updated',
    });

    expect(res['id'], 'item-456');
    expect(res['photo_url'], newUrl);
    expect(auditCalls, 1);
  });
}
