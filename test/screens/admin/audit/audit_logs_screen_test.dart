import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/screens/admin/audit/audit_logs_screen_clean.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/audit_service.dart';

void main() {
  testWidgets('renders list and opens detail dialog', (
    WidgetTester tester,
  ) async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        return [
          {
            'id': 'a1',
            'action_type': 'CREATE',
            'table_name': 'items',
            'record_id': 'i1',
            'admin_user_full_name': 'Admin User',
            'new_values': {'name': 'Test Item'},
            'created_at': '2025-12-10T12:00:00Z',
          },
        ];
      }
      if (name == 'admin_get_all_users') {
        return [
          {'id': 'admin1', 'full_name': 'Admin User'},
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    // initial load triggers async call
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // we don't render the appbar title; the string may appear in dropdown labels
    // Wait for Future to complete and list to render
    await tester.pumpAndSettle();

    expect(find.text('Admin User'), findsOneWidget);
    // We verify admin and details present; action badge may appear multiple times.

    // Tap view details. Ensure it's visible first (horizontal scroll area).
    final viewButton = find.byIcon(Icons.visibility);
    await tester.ensureVisible(viewButton);
    expect(viewButton, findsOneWidget);
    await tester.tap(viewButton);
    await tester.pumpAndSettle();

    expect(find.text('Audit Log Details'), findsOneWidget);
    expect(find.textContaining('Test Item'), findsWidgets);
    // Make sure our new diff section is shown
    expect(find.text('Old vs New values:'), findsOneWidget);
  });

  testWidgets('export CSV shows dialog and can copy', (
    WidgetTester tester,
  ) async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        return [
          {
            'id': 'a1',
            'action_type': 'CREATE',
            'table_name': 'items',
            'record_id': 'i1',
            'admin_user_full_name': 'Admin User',
            'new_values': {'name': 'Test Item'},
            'created_at': '2025-12-10T12:00:00Z',
          },
        ];
      }
      if (name == 'admin_get_all_users') {
        return [
          {'id': 'admin1', 'full_name': 'Admin User'},
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Press export
    final exportFinder = find.byKey(const Key('audit-export-button'));
    expect(exportFinder, findsOneWidget);
    await tester.tap(exportFinder);
    await tester.pumpAndSettle();

    expect(find.text('CSV Export'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    // CSV content should contain the sample value
    expect(find.textContaining('Test Item'), findsOneWidget);
  });

  testWidgets('filters by action type', (WidgetTester tester) async {
    bool calledWithUpdate = false;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        if (params != null && params['p_action_type'] == 'UPDATE') {
          calledWithUpdate = true;
          return [
            {
              'id': 'a2',
              'action_type': 'UPDATE',
              'table_name': 'profiles',
              'record_id': 'u2',
              'admin_user_full_name': 'Other Admin',
              'new_values': {'role': 'admin'},
              'created_at': '2025-12-10T12:00:01Z',
            },
          ];
        }
        return [];
      }
      if (name == 'admin_get_all_users') {
        return [
          {'id': 'admin2', 'full_name': 'Other Admin'},
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Ensure UI has rendered and filters are present.

    // Tap the inline action 'UPDATE' button. Target by key for determinism.
    final updateKey = find.byKey(const Key('audit-action-update-button'));
    expect(updateKey, findsOneWidget);
    // Validate the button exists then call its onPressed handler to simulate a tap.
    await tester.ensureVisible(updateKey);
    // Some test environments can't hit the exact center of semantic wrappers; call onPressed directly.
    final tb = tester.widget<TextButton>(updateKey);
    expect(tb.onPressed, isNotNull);
    tb.onPressed!();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    // Trigger refresh (button in filter card). Call onPressed directly to avoid tap hit-test issues.
    final refreshFinder = find.byKey(const Key('audit-refresh-button'));
    final eb = tester.widget<ElevatedButton>(refreshFinder);
    expect(eb.onPressed, isNotNull);
    eb.onPressed!();
    await tester.pumpAndSettle();

    expect(calledWithUpdate, isTrue);
    expect(find.text('Other Admin'), findsOneWidget);
  });

  testWidgets('filters by table name', (WidgetTester tester) async {
    bool calledWithProfiles = false;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        if (params != null && params['p_table_name'] == 'profiles') {
          calledWithProfiles = true;
          return [
            {
              'id': 'a3',
              'action_type': 'UPDATE',
              'table_name': 'profiles',
              'record_id': 'u3',
              'admin_user_full_name': 'Profile Admin',
              'new_values': {'role': 'editor'},
              'created_at': '2025-12-10T12:00:02Z',
            },
          ];
        }
        return [];
      }
      if (name == 'admin_get_all_users') {
        return [
          {'id': 'admin3', 'full_name': 'Profile Admin'},
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdownFinder = find.byKey(const Key('audit-table-dropdown'));
    expect(dropdownFinder, findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<String?>>(
      dropdownFinder,
    );
    // Call the onChanged handler directly to set the filter, then refresh.
    dropdown.onChanged?.call('profiles');
    await tester.pumpAndSettle();

    final refreshFinder = find.byKey(const Key('audit-refresh-button'));
    final eb = tester.widget<ElevatedButton>(refreshFinder);
    expect(eb.onPressed, isNotNull);
    eb.onPressed!();
    await tester.pumpAndSettle();

    expect(calledWithProfiles, isTrue);
    expect(find.text('Profile Admin'), findsOneWidget);
  });

  testWidgets('filters by record id', (WidgetTester tester) async {
    bool calledWithRecordId = false;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        if (params != null && params['p_record_id'] == 'u2') {
          calledWithRecordId = true;
          return [
            {
              'id': 'a4',
              'action_type': 'UPDATE',
              'table_name': 'profiles',
              'record_id': 'u2',
              'admin_user_full_name': 'Other Admin',
              'new_values': {'role': 'admin'},
              'created_at': '2025-12-10T12:00:01Z',
            },
          ];
        }
        return [];
      }
      if (name == 'admin_get_all_users') {
        return [
          {'id': 'admin4', 'full_name': 'Other Admin'},
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('audit-record-input')), 'u2');
    await tester.pumpAndSettle();

    final refreshFinder = find.byKey(const Key('audit-refresh-button'));
    final eb = tester.widget<ElevatedButton>(refreshFinder);
    expect(eb.onPressed, isNotNull);
    eb.onPressed!();
    await tester.pumpAndSettle();

    expect(calledWithRecordId, isTrue);
    expect(find.text('Other Admin'), findsOneWidget);
  });

  testWidgets('narrow layout does not overflow', (WidgetTester tester) async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        return [
          {
            'id': 'a1',
            'action_type': 'CREATE',
            'table_name': 'items',
            'record_id': 'i1',
            'admin_user_full_name': 'Admin User',
            'new_values': {'name': 'Test Item'},
            'created_at': '2025-12-10T12:00:00Z',
          },
        ];
      }
      if (name == 'admin_get_all_users') {
        return [
          {'id': 'admin1', 'full_name': 'Admin User'},
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    // Set a narrow test device size
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final oldDevicePixelRatio = binding.window.devicePixelRatio;
    binding.window.physicalSizeTestValue = const Size(400, 800);
    binding.window.devicePixelRatioTestValue = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No overflow errors should be thrown; check UI content present
    expect(find.text('Admin User'), findsOneWidget);

    // Reset test window
    binding.window.clearPhysicalSizeTestValue();
    binding.window.devicePixelRatioTestValue = oldDevicePixelRatio;
  });

  testWidgets('pagination next/prev invokes RPC with offsets', (
    WidgetTester tester,
  ) async {
    final calledOffsets = <int>{};
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_audit_logs') {
        calledOffsets.add(params?['p_offset'] ?? 0);
        // Return different row data depending on offset
        return [
          {
            'id': 'p${params?['p_offset'] ?? 0}',
            'action_type': 'UPDATE',
            'table_name': 'profiles',
            'record_id': 'u${params?['p_offset'] ?? 0}',
            'admin_user_full_name': 'Paged Admin ${params?['p_offset'] ?? 0}',
            'new_values': {'role': 'admin'},
            'created_at': '2025-12-10T12:00:01Z',
          },
        ];
      }
      return [];
    }

    final svc = AuditService(null, fakeRpc);
    final adminSvc = AdminService(null, fakeRpc);

    await tester.pumpWidget(
      MaterialApp(
        home: AuditLogsScreen(
          wrapWithAdminLayout: false,
          auditServiceOverride: svc,
          adminServiceOverride: adminSvc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Click 'next' (chevron_right)
    final nextFinder = find
        .ancestor(
          of: find.byIcon(Icons.chevron_right),
          matching: find.byType(IconButton),
        )
        .last;
    final nextBtn = tester.widget<IconButton>(nextFinder);
    expect(nextBtn.onPressed, isNotNull);
    nextBtn.onPressed!();
    await tester.pumpAndSettle();

    expect(calledOffsets.contains(50), isTrue);
    // debug: calledOffsets after next
    expect(find.text('Paged Admin 50'), findsOneWidget);

    // Click 'prev' (chevron_left) to return to 0
    final prevFinder = find
        .ancestor(
          of: find.byIcon(Icons.chevron_left),
          matching: find.byType(IconButton),
        )
        .last;
    final prevBtn = tester.widget<IconButton>(prevFinder);
    expect(prevBtn.onPressed, isNotNull);
    prevBtn.onPressed!();
    await tester.pumpAndSettle();

    expect(calledOffsets.contains(0), isTrue);
    // debug: calledOffsets after prev
    // debug: texts after pagination
    expect(find.text('Paged Admin 0'), findsOneWidget);
  });
}
