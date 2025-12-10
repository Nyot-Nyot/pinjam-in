import 'dart:io';

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

  test('saveRowsToCsvFile writes file to temp dir and returns path', () async {
    final rows = [
      {'name': 'Alice', 'count': 2, 'email': 'alice@example.com'},
      {'name': 'Bob', 'count': 3, 'email': 'bob@example.com'},
    ];
    final dir = Directory.systemTemp.createTempSync('report_test');
    final path = await ReportService.instance.saveRowsToCsvFile(
      rows,
      filename: 'test_report',
      directoryPath: dir.path,
    );
    final file = File(path);
    expect(file.existsSync(), isTrue);
    final text = file.readAsStringSync();
    expect(text, contains('name,count,email'));
    // cleanup
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
