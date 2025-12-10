import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/models/loan_item.dart';
import 'package:pinjam_in/screens/admin/storage/file_browser_screen.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/persistence_service.dart';
import 'package:pinjam_in/services/shared_prefs_persistence.dart';
import 'package:pinjam_in/services/storage_service.dart';

class FakeAdminService extends AdminService {
  FakeAdminService() : super(null, null, null);
  @override
  Future<bool> deleteStorageObject(String path, {String? bucketId}) async {
    return true;
  }
}

class FakeAdminServiceFails extends AdminService {
  FakeAdminServiceFails() : super(null, null, null);
  @override
  Future<bool> deleteStorageObject(String path, {String? bucketId}) async {
    return false;
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
    // Re-find the checkbox in the newly-built widget tree
    final fileCheckbox2 = find.descendant(
      of: find.widgetWithText(ListTile, 'photo1.jpg'),
      matching: find.byType(Checkbox),
    );
    expect(fileCheckbox2, findsOneWidget);
    await tester.tap(fileCheckbox2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Delete (1)'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Delete (1)'), findsOneWidget);
    // Confirm bulk delete dialog (two-step: tap delete button)
    await tester.tap(find.text('Delete (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Tap Delete on the dialog
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // After deletion the file list should refresh and show no items if only one was present
    // (We can't assert delete is 100% here but we can assert snack bar message appears)
    expect(find.text('Files deleted'), findsOneWidget);

    // Test delete failure: replace admin service with failing fake and trigger
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileBrowserScreen(
            wrapWithAdminLayout: false,
            storageService: storageSvc,
            adminService: FakeAdminServiceFails(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Use the per-item delete button to test failure mode
    final deleteIcon = find
        .descendant(
          of: find.widgetWithText(ListTile, 'photo1.jpg'),
          matching: find.byIcon(Icons.delete_forever),
        )
        .first;
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Confirm Delete on the dialog
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Should show some snackbar indicating error
    expect(find.byType(SnackBar), findsWidgets);

    // Test download flow: tap download icon and select 'Open in Browser'
    final downloadButton = find
        .descendant(
          of: find.widgetWithText(ListTile, 'photo1.jpg'),
          matching: find.byIcon(Icons.download),
        )
        .first;
    expect(downloadButton, findsOneWidget);
    await tester.tap(downloadButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Bottom sheet options should be present
    expect(find.text('Open in Browser'), findsOneWidget);
    await tester.tap(find.text('Open in Browser'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // SnackBar should show a message (success or failure feedback)
    expect(find.byType(SnackBar), findsWidgets);

    // Test download with unsupported persistence
    ServiceLocator.setPersistenceService(SharedPrefsPersistence());
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // With SharedPrefsPersistence the download icon is not shown because it doesn't provide signed URLs
    final downloadButton2 = find.descendant(
      of: find.widgetWithText(ListTile, 'photo1.jpg'),
      matching: find.byIcon(Icons.download),
    );
    expect(downloadButton2, findsNothing);
  });
}
