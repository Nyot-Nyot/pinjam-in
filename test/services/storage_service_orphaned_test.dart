import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/storage_service.dart';

void main() {
  test('listOrphanedFiles returns parsed list from RPC', () async {
    final fakeRpc = (String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_list_orphaned_storage_files');
      return [
        {
          'name': 'orph1.jpg',
          'metadata': {'size': '1024'},
          'bucket_id': 'item_photos',
        },
        {
          'name': 'orph2.png',
          'metadata': {'size': '2048'},
          'bucket_id': 'item_photos',
        },
      ];
    };

    final svc = StorageService(null, fakeRpc);
    final res = await svc.listOrphanedFiles(limit: 5);
    expect(res, isA<List<Map<String, dynamic>>>());
    expect(res.length, 2);
    expect(res[0]['name'], 'orph1.jpg');
    expect(res[1]['name'], 'orph2.png');
  });
}
