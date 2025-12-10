import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/report_service.dart';

void main() {
  test('generatePdfBytes returns non-empty bytes', () async {
    final rows = [
      {'name': 'Alice', 'count': 2},
      {'name': 'Bob', 'count': 3},
    ];
    final bytes = await ReportService.instance.generatePdfBytes(rows);
    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(0));
  });

  test('saveRowsToPdfFile writes pdf to temp dir', () async {
    final rows = [
      {'name': 'Alice', 'count': 2},
      {'name': 'Bob', 'count': 3},
    ];
    final dir = Directory.systemTemp.createTempSync('report_pdf_test');
    final path = await ReportService.instance.saveRowsToPdfFile(
      rows,
      filename: 'test_pdf',
      directoryPath: dir.path,
    );
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
