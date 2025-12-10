import 'dart:ui' as ui;

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
          ];
        }
        return <dynamic>[];
      });
}

class FakeAdminService extends AdminService {
  FakeAdminService() : super(null, null, null);
}

void main() {
  testWidgets('StorageCleanupScreen does not overflow on narrow widths', (
    tester,
  ) async {
    // Set a narrow screen width similar to the reported overflow 336px.
    tester.binding.window.physicalSizeTestValue = const ui.Size(336, 640);
    tester.binding.window.devicePixelRatioTestValue = 1.0;

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

    // Allow any frames to render
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Storage Cleanup'), findsOneWidget);
    // Stats text present and should not overflow (no exception is thrown during build)
    expect(find.textContaining('orphaned files'), findsOneWidget);

    // Reset the window size to avoid impacting other tests
    tester.binding.window.clearPhysicalSizeTestValue();
    tester.binding.window.clearDevicePixelRatioTestValue();
  });
}
