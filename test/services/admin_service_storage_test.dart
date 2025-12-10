import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/service_exception.dart';

class _FakeFrom {
  final bool shouldThrow;
  _FakeFrom(this.shouldThrow);
  Future<void> remove(List<String> paths) async {
    if (shouldThrow) throw Exception('storage failure');
    return;
  }
}

class _FakeStorage {
  final bool shouldThrow;
  _FakeStorage(this.shouldThrow);
  _FakeFrom from(String bucket) => _FakeFrom(shouldThrow);
}

class _FakeClient {
  final bool shouldThrow;
  _FakeClient(this.shouldThrow);
  get storage => _FakeStorage(shouldThrow);
}

void main() {
  test(
    'deleteStorageObject uses storage client remove and returns true',
    () async {
      final client = _FakeClient(false);
      final svc = AdminService(
        client,
        (name, {params}) async => <dynamic>[],
        null,
      );
      final ok = await svc.deleteStorageObject('user1/photo1.jpg');
      expect(ok, isTrue);
    },
  );

  test(
    'deleteStorageObject throws ServiceException on storage error',
    () async {
      final client = _FakeClient(true);
      final svc = AdminService(
        client,
        (name, {params}) async => <dynamic>[],
        null,
      );
      try {
        await svc.deleteStorageObject('user1/photo1.jpg');
        fail('should have thrown');
      } catch (e) {
        expect(e, isA<ServiceException>());
      }
    },
  );

  test(
    'deleteStorageObject throws ServiceException when listing still contains object',
    () async {
      final client = _FakeClient(false);
      final svc = AdminService(client, (name, {params}) async {
        if (name == 'admin_list_storage_files') {
          return [
            {
              'id': '1',
              'name': 'user1/photo1.jpg',
              'owner': null,
              'bucket_id': 'item_photos',
              'size_bytes': 1024,
              'created_at': DateTime.now().toIso8601String(),
              'metadata': <String, dynamic>{},
            },
          ];
        }
        return <dynamic>[];
      }, null);
      try {
        await svc.deleteStorageObject('user1/photo1.jpg');
        fail('should have thrown');
      } catch (e) {
        expect(e, isA<ServiceException>());
      }
    },
  );

  test('deleteStorageObject succeeds when listing clears after retry', () async {
    final client = _FakeClient(false);
    var callCount = 0;
    final svc = AdminService(client, (name, {params}) async {
      if (name == 'admin_list_storage_files') {
        callCount += 1;
        // On first listing: return non-empty so it appears to still exist.
        // On subsequent listing(s) return empty to simulate eventual consistency.
        if (callCount == 1) {
          return [
            {
              'id': '1',
              'name': 'user1/photo1.jpg',
              'owner': null,
              'bucket_id': 'item_photos',
              'size_bytes': 1024,
              'created_at': DateTime.now().toIso8601String(),
              'metadata': <String, dynamic>{},
            },
          ];
        }
        return <dynamic>[];
      }
      return <dynamic>[];
    }, null);
    final ok = await svc.deleteStorageObject('user1/photo1.jpg');
    expect(ok, isTrue);
  });
}
