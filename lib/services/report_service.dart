import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'admin_service.dart';
import 'service_exception.dart';

/// Light wrapper for generating simple admin reports.
class ReportService {
  final AdminService _admin = AdminService.instance;

  static final ReportService instance = ReportService._();
  ReportService._();

  /// Returns user summary rows. For now, uses admin_get_top_users RPC as a
  /// representative summary for the top users. Additional per-user metrics may
  /// be added later.
  Future<List<Map<String, dynamic>>> getUserSummary({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    try {
      final rows = await _admin.getTopActiveUsers(limit: limit);
      return rows;
    } catch (e) {
      throw ServiceException(e.toString(), cause: e);
    }
  }

  /// Returns items that are overdue. Uses getAllItems fallback with status 'overdue'.
  Future<List<Map<String, dynamic>>> getOverdueItems({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    try {
      final rows = await _admin.getAllItems(
        limit: limit,
        offset: 0,
        status: 'overdue',
      );
      return rows;
    } catch (e) {
      throw ServiceException(e.toString(), cause: e);
    }
  }

  /// Returns summary stats for items, as a single-row list. Uses
  /// admin_get_item_statistics if available.
  Future<List<Map<String, dynamic>>> getItemsSummary() async {
    try {
      final stats = await _admin.getItemStatistics();
      if (stats == null) return <Map<String, dynamic>>[];
      return [stats];
    } catch (e) {
      throw ServiceException(e.toString(), cause: e);
    }
  }

  /// Export rows to CSV string. Uses the union of keys found in first row
  /// (sorted) as header. Escapes values via double quotes if needed.
  String exportToCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';
    final header = rows.first.keys.toList();
    final buffer = StringBuffer();
    buffer.writeln(header.map(_escapeCsv).join(','));
    for (final r in rows) {
      final row = header.map((k) => _escapeCsv('${r[k] ?? ''}')).join(',');
      buffer.writeln(row);
    }
    return buffer.toString();
  }

  String _escapeCsv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      final escaped = s.replaceAll('"', '""');
      return '"$escaped"';
    }
    return s;
  }

  /// Save CSV rows to a file and return the path. Accepts optional directoryPath
  /// for testing to avoid relying on path_provider.
  Future<String> saveRowsToCsvFile(
    List<Map<String, dynamic>> rows, {
    String filename = 'report',
    String? directoryPath,
  }) async {
    if (rows.isEmpty) throw Exception('No data to export');
    try {
      final header = rows.first.keys.toList();
      final csvConverter = const ListToCsvConverter();
      final data = <List<dynamic>>[];
      data.add(header);
      for (final r in rows) {
        final row = header.map((k) => r[k] ?? '').toList();
        data.add(row);
      }
      final csvString = csvConverter.convert(data);

      if (kIsWeb) {
        // On web, return CSV string as a pseudo-path; callers should fallback to clipboard.
        return csvString;
      }

      final dir = directoryPath != null
          ? Directory(directoryPath)
          : await getTemporaryDirectory();
      final file = File('${dir.path}/$filename.csv');
      await file.writeAsString(csvString, flush: true, encoding: utf8);
      return file.path;
    } catch (e) {
      throw ServiceException(e.toString(), cause: e);
    }
  }

  /// Save CSV file and trigger the share dialog (mobile/desktop). On Web the
  /// csvString will be returned as a pseudo path and should be handled by the caller.
  Future<String> saveAndShareRowsAsCsv(
    List<Map<String, dynamic>> rows, {
    String filename = 'report',
    String? directoryPath,
  }) async {
    final path = await saveRowsToCsvFile(
      rows,
      filename: filename,
      directoryPath: directoryPath,
    );
    if (kIsWeb) return path; // caller can handle string
    try {
      try {
        await Share.shareXFiles([XFile(path)], text: 'CSV report');
      } catch (_) {
        // fallback to generic share
        await Share.share('CSV report: $path');
      }
    } catch (e) {
      // ignore share errors, still return the path
    }
    return path;
  }

  /// Generate a simple PDF document from rows and return bytes
  Future<Uint8List> generatePdfBytes(
    List<Map<String, dynamic>> rows, {
    String title = 'Report',
  }) async {
    if (rows.isEmpty) throw Exception('No data to export');
    final doc = pw.Document();
    final headers = rows.first.keys.toList();
    final data = rows
        .map((r) => headers.map((h) => r[h]?.toString() ?? '').toList())
        .toList();

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Generated: ${DateTime.now().toIso8601String()}'),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(headers: headers, data: data),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Save PDF to file and return path
  Future<String> saveRowsToPdfFile(
    List<Map<String, dynamic>> rows, {
    String filename = 'report_pdf',
    String? directoryPath,
  }) async {
    try {
      final bytes = await generatePdfBytes(rows);
      if (kIsWeb) {
        // For web, return base64 string as a pseudo-path
        return base64Encode(bytes);
      }
      final dir = directoryPath != null
          ? Directory(directoryPath)
          : await getTemporaryDirectory();
      final file = File('${dir.path}/$filename.pdf');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      throw ServiceException(e.toString(), cause: e);
    }
  }

  Future<String> saveAndShareRowsAsPdf(
    List<Map<String, dynamic>> rows, {
    String filename = 'report_pdf',
    String? directoryPath,
  }) async {
    final path = await saveRowsToPdfFile(
      rows,
      filename: filename,
      directoryPath: directoryPath,
    );
    if (kIsWeb) return path;
    try {
      await Share.shareXFiles([XFile(path)], text: 'PDF report');
    } catch (_) {
      await Share.share('PDF report: $path');
    }
    return path;
  }
}
