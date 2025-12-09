import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/screens/admin/storage/storage_dashboard.dart';
import 'package:pinjam_in/services/storage_service.dart';

class FakeStorageService extends StorageService {
  FakeStorageService()
    : super(null, ((name, {params}) async {
        switch (name) {
          case 'admin_get_storage_stats':
            return {
              'total_files': 10,
              'total_size_bytes': 1048576,
              'orphaned_files': 2,
              'items_with_photos': 8,
            };
          case 'admin_get_storage_by_user':
            return [
              {
                'user_id': '1',
                'user_email': 'a@x.com',
                'total_size_bytes': 500,
                'file_count': 2,
              },
              {
                'user_id': '2',
                'user_email': 'b@x.com',
                'total_size_bytes': 300,
                'file_count': 1,
              },
            ];
          case 'admin_get_storage_file_type_distribution':
            return [
              {'extension': 'jpg', 'file_count': 5, 'total_size_bytes': 5120},
              {'extension': 'png', 'file_count': 2, 'total_size_bytes': 2048},
            ];
          default:
            return {};
        }
      }));
}

void main() {
  testWidgets('StorageDashboard renders stats', (tester) async {
    final svc = FakeStorageService();
    await tester.pumpWidget(
      MaterialApp(
        home: StorageDashboardScreen(service: svc, wrapWithAdminLayout: false),
      ),
    );

    // Allow async fetch
    await tester.pumpAndSettle();

    expect(find.text('Storage Dashboard'), findsOneWidget);
    expect(find.text('Storage usage (MB)'), findsOneWidget);
    expect(find.textContaining('Total size (MB)'), findsOneWidget);
    expect(find.text('Total files'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    // Top users section
    expect(find.text('Top users by storage (top 10)'), findsOneWidget);
    expect(find.text('a@x.com'), findsOneWidget);
    // File type distribution
    expect(find.text('File type distribution'), findsOneWidget);
    expect(find.text('Orphaned files'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('StorageDashboard layout works on narrow screens', (
    tester,
  ) async {
    // set a narrow viewport to simulate smaller phone width
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final svc = FakeStorageService();
    await tester.pumpWidget(
      MaterialApp(
        home: StorageDashboardScreen(service: svc, wrapWithAdminLayout: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storage Dashboard'), findsOneWidget);
    // Ensure primary card labels are present and layout completes without overflow
    expect(find.text('Total files'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });
}
