import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/screens/admin/storage/storage_cleanup_screen.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/storage_service.dart';

class FakeStorageService extends StorageService {
  FakeStorageService()
    : super(null, (name, {params}) async {
        if (name == 'admin_list_orphaned_storage_files') {
          return [
            {
              'name': 'user1/photo1.jpg',
              'size_bytes': 1024,
              'bucket_id': 'item_photos',
            },
            {
              'name': 'orph/orphan.jpg',
              'size_bytes': 2048,
              'bucket_id': 'item_photos',
            },
          ];
        }
        return <dynamic>[];
      });
}

class FakeAdminService extends AdminService {
  FakeAdminService() : super(null, null, null);

  @override
  Future<Map<String, dynamic>> deleteStorageObjects(
    List<String> paths, {
    String? bucketId,
  }) async {
    // pretend we deleted one and failed one
    return {
      'deleted': [paths.first],
      'failed': [
        {'path': paths.last, 'error': 'simulated'},
      ],
    };
  }
}

void main() {
  testWidgets('StorageCleanupScreen lists orphaned files and deletes selected', (
    tester,
  ) async {
    final storageSvc = FakeStorageService();
    final adminSvc = FakeAdminService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorageCleanupScreen(
            storageService: storageSvc,
            adminService: adminSvc,
          ),
        ),
      ),
    );

    // Wait for the initial load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Page title present
    expect(find.text('Storage Cleanup'), findsOneWidget);

    // Should show the orphaned file names
    expect(find.text('photo1.jpg'), findsOneWidget);
    expect(find.text('orphan.jpg'), findsOneWidget);

    // Select both items using checkboxes
    final cb1 = find.descendant(
      of: find.widgetWithText(ListTile, 'photo1.jpg'),
      matching: find.byType(Checkbox),
    );
    expect(cb1, findsOneWidget);
    await tester.tap(cb1);
    await tester.pump();

    final cb2 = find.descendant(
      of: find.widgetWithText(ListTile, 'orphan.jpg'),
      matching: find.byType(Checkbox),
    );
    expect(cb2, findsOneWidget);
    await tester.tap(cb2);
    await tester.pump();

    // Delete button should show count
    expect(find.text('Delete (2)'), findsOneWidget);

    // Trigger delete (dialog confirmation)
    await tester.tap(find.text('Delete (2)'));
    await tester.pump();

    // Confirm the dialog's Delete button
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Expect Snackbar showing 'Deleted 1 files, failed 1' (from our fake admin service)
    expect(find.textContaining('Deleted 1 files, failed 1'), findsOneWidget);
  });
}
