import '../../core/services/database_service.dart';
import '../models/audit_log_entry.dart';

class AuditLogRepository {
  final _db = DatabaseService.instance;

  Future<List<AuditLogEntry>> listRecent({
    int limit = 200,
    String? action,
  }) async {
    final where = action != null && action.isNotEmpty ? 'WHERE a.action = ?' : '';
    final args = action != null && action.isNotEmpty ? [action, limit] : [limit];
    final rows = await _db.raw('''
      SELECT a.id, a.user_id, a.action, a.details, a.created_at, u.username
      FROM audit_log a
      LEFT JOIN users u ON u.id = a.user_id
      $where
      ORDER BY a.created_at DESC
      LIMIT ?
    ''', args);

    return rows.map(AuditLogEntry.fromMap).toList();
  }

  Future<Map<String, int>> countByActionToday() async {
    final start = DateTime.now();
    final dayStart = DateTime(start.year, start.month, start.day);
    final rows = await _db.raw('''
      SELECT action, COUNT(*) as cnt
      FROM audit_log
      WHERE created_at >= ?
      GROUP BY action
    ''', [dayStart.toIso8601String()]);
    return {
      for (final r in rows) r['action'] as String: r['cnt'] as int,
    };
  }
}
