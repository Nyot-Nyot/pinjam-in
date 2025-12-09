import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/models/loan_item.dart';
import 'package:pinjam_in/screens/admin/storage/file_detail_screen.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/persistence_service.dart';
import 'package:pinjam_in/services/storage_service.dart';

class FakeAdminService extends AdminService {
  FakeAdminService() : super(null, null, null);
  final List<String> deletedPaths = [];
  bool lastClearRelated = false;
  @override
  Future<bool> deleteStorageObject(String path, {String? bucketId}) async {
    deletedPaths.add(path);
    lastClearRelated = true;
    return true;
  }

  @override
  Future<bool> deleteStorageObjectAndClearItems(
    String path, {
    String? bucketId,
    bool clearRelated = true,
  }) async {
    deletedPaths.add(path);
    lastClearRelated = clearRelated;
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
  Future<List<LoanItem>> loadActive() async => <LoanItem>[];

  @override
  Future<List<LoanItem>> loadHistory() async => <LoanItem>[];

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

    final adminSvc = FakeAdminService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileDetailScreen(
            wrapWithAdminLayout: false,
            fileData: file,
            adminService: adminSvc,
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

    // Test download action does not throw and keeps UI intact
    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('photo1.jpg'), findsOneWidget);

    // Test delete - confirm dialog and deletion Snackbar
    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Delete file'), findsOneWidget);
    // Checkbox exists for clearing related items (default true)
    expect(
      find.textContaining('Clear related item photo_url fields'),
      findsOneWidget,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('File deleted'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(adminSvc.deletedPaths.isNotEmpty, true);
    expect(adminSvc.lastClearRelated, true);
  });
}
