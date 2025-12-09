import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/models/loan_item.dart';
import 'package:pinjam_in/screens/admin/storage/file_browser_screen.dart';
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
  Future<List<LoanItem>> loadActive() async => <LoanItem>[];

  @override
  Future<List<LoanItem>> loadHistory() async => <LoanItem>[];

  @override
  Future<void> saveActive(List items) async {}

  @override
  Future<void> saveHistory(List items) async {}

  // Provide an optional getSignedUrl for the StorageImage dynamic detection.
  Future<String?> getSignedUrl(String path) async => null;
}

void main() {
  testWidgets('FileBrowser renders and lists files', (tester) async {
    final now = DateTime.now();
    final fakeList = [
      {
        'id': '111',
        'name': 'user1/photo1.jpg',
        'owner': 'uuid1',
        'bucket_id': 'item_photos',
        'size_bytes': 1024,
        'created_at': now.toIso8601String(),
        'metadata': <String, dynamic>{},
      },
    ];

    final storageSvc = StorageService(null, (name, {params}) async {
      if (name == 'admin_list_storage_files') return fakeList;
      return <dynamic>[];
    });

    ServiceLocator.setPersistenceService(FakePersistence());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileBrowserScreen(
            wrapWithAdminLayout: false,
            storageService: storageSvc,
            adminService: FakeAdminService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('File Browser'), findsOneWidget);
    // Should show the file name
    expect(find.text('user1/photo1.jpg'), findsOneWidget);
    // Buttons present
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);
  });
}
