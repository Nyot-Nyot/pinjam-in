import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/report_service.dart';

void main() {
  test('exportToCsv converts rows to CSV string', () {
    final rows = [
      {'name': 'Alice', 'count': 2, 'email': 'alice@example.com'},
      {'name': 'Bob', 'count': 3, 'email': 'bob@example.com'},
    ];
    final csv = ReportService.instance.exportToCsv(rows);
    expect(csv, contains('name,count,email'));
    expect(csv, contains('Alice'));
    expect(csv, contains('Bob'));
  });
}
