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
}
