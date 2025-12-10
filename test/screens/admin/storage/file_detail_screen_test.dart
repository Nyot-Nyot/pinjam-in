import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/screens/admin/storage/file_detail_screen.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/persistence_service.dart';
import 'package:pinjam_in/services/storage_service.dart';

class FakeAdminService extends AdminService {
  FakeAdminService() : super(null, null, null);
  @override
  Future<bool> deleteStorageObject(String path, {String? bucketId}) async {
    return true;
  }
}

class FakePersistence extends PersistenceService {
  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> invalidateCache({String? itemId}) async {}

  @override
  Future<String?> currentUserId() async => null;

  @override
  Future<List<dynamic>> loadActive() async => <dynamic>[];

  @override
  Future<List<dynamic>> loadHistory() async => <dynamic>[];

  @override
  Future<void> saveActive(List items) async {}

  @override
  Future<void> saveHistory(List items) async {}

  Future<String?> getSignedUrl(String path) async =>
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAoMBg9f8CUcAAAAASUVORK5CYII=';
}

void main() {
  testWidgets('FileDetail renders details and actions', (tester) async {
    final now = DateTime.now();
    final file = {
      'id': '111',
      'name': 'user1/photo1.jpg',
      'owner': 'uuid1',
      'bucket_id': 'item_photos',
      'size_bytes': 1024,
      'created_at': now.toIso8601String(),
      'metadata': <String, dynamic>{},
    };

    ServiceLocator.setPersistenceService(FakePersistence());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileDetailScreen(
            wrapWithAdminLayout: false,
            fileData: file,
            adminService: FakeAdminService(),
            storageService: StorageService(null, (name, {params}) async {
              return <dynamic>[];
            }),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // File basename
    expect(find.text('photo1.jpg'), findsOneWidget);
    // Metadata labels
    expect(find.text('Size'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Related Item'), findsOneWidget);
    // Action icons: download, fullscreen, delete
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);

    // Test download action shows snackbar
    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Download link'), findsOneWidget);

    // Test delete - confirm dialog and deletion Snackbar
    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('File deleted'), findsOneWidget);
  });
}
