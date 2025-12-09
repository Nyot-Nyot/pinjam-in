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
      final svc = AdminService(client, null, null);
      final ok = await svc.deleteStorageObject('user1/photo1.jpg');
      expect(ok, isTrue);
    },
  );

  test(
    'deleteStorageObject throws ServiceException on storage error',
    () async {
      final client = _FakeClient(true);
      final svc = AdminService(client, null, null);
      try {
        await svc.deleteStorageObject('user1/photo1.jpg');
        fail('should have thrown');
      } catch (e) {
        expect(e, isA<ServiceException>());
      }
    },
  );
}
