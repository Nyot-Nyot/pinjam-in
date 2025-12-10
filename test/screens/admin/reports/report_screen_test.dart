import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/screens/admin/reports/report_screen.dart';

void main() {
  testWidgets('ReportScreen renders controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReportScreen(wrapWithAdminLayout: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.byType(DropdownButton<ReportType>), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
  });
}
