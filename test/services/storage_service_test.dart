import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/storage_service.dart';

void main() {
  group('StorageService', () {
    test('getStorageStats returns parsed map from Map response', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        return {
          'total_files': 42,
          'total_size_bytes': 12345678,
          'orphaned_count': 3,
          'items_with_photos': 29,
        };
      }

      final s = StorageService(null, fakeRpc);

      final stats = await s.getStorageStats();

      expect(stats['total_files'], 42);
      expect(stats['total_size_bytes'], 12345678);
      expect(stats['orphaned_count'], 3);
      expect(stats['items_with_photos'], 29);
    });

    test('getStorageStats returns parsed map from List response', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        return [
          {
            'total_files': 5,
            'total_size_bytes': 1000,
            'orphaned_count': 0,
            'items_with_photos': 5,
          },
        ];
      }

      final s = StorageService(null, fakeRpc);

      final stats = await s.getStorageStats();
      expect(stats['total_files'], 5);
    });

    test('getStorageStats wraps RPC errors into ServiceException', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        throw Exception('oh no');
      }

      final s = StorageService(null, fakeRpc);

      try {
        await s.getStorageStats();
        fail('should have thrown');
      } catch (e) {
        expect(e.toString().contains('oh no'), true);
      }
    });

    test('getStorageStats normalizes numeric string values', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        return {
          'total_files': '77',
          'total_size_bytes': '2048',
          'items_with_photos': '20',
        };
      }

      final s = StorageService(null, fakeRpc);

      final stats = await s.getStorageStats();
      expect(stats['total_files'], 77);
      expect(stats['total_size_bytes'], 2048);
      expect(stats['items_with_photos'], 20);
    });

    test('getStorageStats normalizes alternate key names', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        return {
          'total_files': '7',
          'total_size': '4096',
          'orphaned_count': '2',
        };
      }

      final s = StorageService(null, fakeRpc);
      final stats = await s.getStorageStats();
      expect(stats['total_files'], 7);
      expect(stats['total_size_bytes'], 4096);
      expect(stats['orphaned_files'], 2);
    });

    test('getStorageStats passes bucketId to RPC params', () async {
      Map<String, dynamic>? capturedParams;
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        capturedParams = params;
        return {
          'total_files': 1,
          'total_size_bytes': 100,
          'items_with_photos': 0,
        };
      }

      final s = StorageService(null, fakeRpc);
      final stats = await s.getStorageStats(bucketId: 'item_photos');
      expect(stats['total_files'], 1);
      expect(capturedParams, isNotNull);
      expect(capturedParams!['p_bucket_id'], 'item_photos');
    });

    test('getStorageByUser returns top users', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        if (name == 'admin_get_storage_by_user') {
          return [
            {
              'user_id': '00000000-0000-0000-0000-000000000001',
              'user_email': 'a@x.com',
              'total_size_bytes': 1024,
              'file_count': 2,
            },
            {
              'user_id': '00000000-0000-0000-0000-000000000002',
              'user_email': 'b@x.com',
              'total_size_bytes': 512,
              'file_count': 1,
            },
          ];
        }
        return {};
      }

      final s = StorageService(null, fakeRpc);
      final rows = await s.getStorageByUser(bucketId: 'item_photos', limit: 10);
      expect(rows.length, 2);
      expect(rows.first['user_email'], 'a@x.com');
    });

    test('getFileTypeDistribution returns counts', () async {
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        if (name == 'admin_get_storage_file_type_distribution') {
          return [
            {'extension': 'jpg', 'file_count': 10, 'total_size_bytes': 10240},
            {'extension': 'png', 'file_count': 5, 'total_size_bytes': 2048},
          ];
        }
        return {};
      }

      final s = StorageService(null, fakeRpc);
      final dist = await s.getFileTypeDistribution(bucketId: 'item_photos');
      expect(dist.length, 2);
      expect(dist.first['extension'], 'jpg');
    });

    test('listFiles returns file list and forwards params', () async {
      Map<String, dynamic>? capturedParams;
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        capturedParams = params;
        if (name == 'admin_list_storage_files') {
          return [
            {
              'id': 'abc',
              'name': 'user1/photo1.jpg',
              'owner': '00000000-0000-0000-0000-000000000001',
              'bucket_id': 'item_photos',
              'size_bytes': 1024,
              'created_at': DateTime.now().toIso8601String(),
              'metadata': {},
            },
          ];
        }
        return [];
      }

      final s = StorageService(null, fakeRpc);
      final rows = await s.listFiles(
        bucketId: 'item_photos',
        limit: 10,
        offset: 0,
      );
      expect(rows.length, 1);
      expect(rows.first['name'], 'user1/photo1.jpg');
      expect(capturedParams, isNotNull);
      expect(capturedParams!['p_bucket_id'], 'item_photos');
      expect(capturedParams!['p_limit'], 10);
      expect(capturedParams!['p_offset'], 0);
    });
  });
}
