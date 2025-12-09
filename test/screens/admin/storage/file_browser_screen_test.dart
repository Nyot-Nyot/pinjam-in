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

  // Provide an optional getSignedUrl for the StorageImage dynamic detection.
  // Return a small 1x1 PNG data URI so CachedNetworkImage does not attempt HTTP,
  // which is disabled in widget tests.
  Future<String?> getSignedUrl(String path) async =>
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAoMBg9f8CUcAAAAASUVORK5CYII=';
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
      {
        'id': '222',
        'name': 'orphaned_photo.jpg',
        'owner': null,
        'bucket_id': 'item_photos',
        'size_bytes': 2048,
        'created_at': now.toIso8601String(),
        'metadata': <String, dynamic>{},
      },
    ];

    final storageSvc = StorageService(null, (name, {params}) async {
      if (name == 'admin_list_storage_files') return fakeList;
      return <dynamic>[];
    });

    ServiceLocator.setPersistenceService(FakePersistence());
    final adminSvc = FakeAdminService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileBrowserScreen(
            wrapWithAdminLayout: false,
            storageService: storageSvc,
            adminService: adminSvc,
          ),
        ),
      ),
    );

    // Do not use pumpAndSettle unbounded as network placeholders in CachedNetworkImage
    // use continuously-animating indicators in tests; pump a few frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('File Browser'), findsOneWidget);
    // Should show the (basename) file name
    expect(find.text('photo1.jpg'), findsOneWidget);
    // Buttons present
    expect(find.byIcon(Icons.open_in_new), findsWidgets);
    expect(find.byIcon(Icons.download), findsWidgets);
    expect(find.byIcon(Icons.delete_forever), findsWidgets);
    // The data URI signed URL should render an Image widget in the list tile
    final imgFinder = find.descendant(
      of: find.widgetWithText(ListTile, 'photo1.jpg'),
      matching: find.byType(Image),
    );
    expect(imgFinder, findsOneWidget);
    // Ensure the 'Download to device' button exists and works (uses data URI)
    expect(find.byIcon(Icons.save_alt), findsWidgets);
    // Trigger the first file's 'Download to device' button
    final downloadToDeviceButton = find.descendant(
      of: find.widgetWithText(ListTile, 'photo1.jpg'),
      matching: find.byIcon(Icons.save_alt),
    );
    expect(downloadToDeviceButton, findsOneWidget);
    await tester.tap(downloadToDeviceButton);
    await tester.pump();
    // The fake download uses a data URI and writes quickly; allow time for dialog and write
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    // Ensure tapping the download button does not crash and UI remains unchanged
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('photo1.jpg'), findsOneWidget);

    // Orphaned filter: toggle orphaned only then expect only orphaned item
    final orphanedCheckbox = find.descendant(
      of: find.widgetWithText(Row, 'Orphaned only'),
      matching: find.byType(Checkbox),
    );
    expect(orphanedCheckbox, findsOneWidget);
    await tester.ensureVisible(orphanedCheckbox);
    await tester.tap(orphanedCheckbox);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('orphaned_photo.jpg'), findsOneWidget);
    expect(find.text('photo1.jpg'), findsNothing);

    // Toggle off orphaned filter and test bulk selection and delete (tap the checkbox)
    await tester.ensureVisible(orphanedCheckbox);
    await tester.tap(orphanedCheckbox);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Select first file's checkbox (search inside the list tile for the filename)
    final fileCheckbox = find.descendant(
      of: find.widgetWithText(ListTile, 'photo1.jpg'),
      matching: find.byType(Checkbox),
    );
    expect(fileCheckbox, findsOneWidget);
    await tester.tap(fileCheckbox);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Delete (1)'), findsOneWidget);
    // Confirm bulk delete dialog (two-step: tap delete button)
    await tester.tap(find.textContaining('Delete (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Ensure checkbox for clearing related items is present (default true)
    expect(
      find.textContaining('Clear related item photo_url fields'),
      findsOneWidget,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Tap Delete on the dialog
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Allow time for delete RPCs and UI updates
    await tester.pump(const Duration(seconds: 1));
    // After deletion the file list should refresh and we should have called the admin service
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Verify admin service received the delete request and clearing related items
    expect(adminSvc.deletedPaths.isNotEmpty, true);
    expect(adminSvc.lastClearRelated, true);
    // We have the FakeAdminService in the widget tree — find and assert
    // The test injected FakeAdminService, so we can assert directly on instance
    // (Not accessible via widget tree); instead, use the instance we created above
    // The fake admin service is passed in as FakeAdminService() in the test above
    // so it's in scope as `FakeAdminService()` variable not recorded — change test to use a named variable
  });
}
