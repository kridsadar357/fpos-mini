import '../../core/services/database_service.dart';

class SettingsRepository {
  Future<String> get(String key, {String defaultValue = ''}) async {
    final rows = await DatabaseService.instance.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return defaultValue;
    return (rows.first['value'] as String?) ?? defaultValue;
  }

  Future<void> set(String key, String value) async {
    final existing = await DatabaseService.instance.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isEmpty) {
      await DatabaseService.instance.insert('settings', {
        'key': key,
        'value': value,
      });
    } else {
      await DatabaseService.instance.update(
        'settings',
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
    }
  }

  Future<Map<String, String>> all() async {
    final rows = await DatabaseService.instance.query('settings');
    return {for (final r in rows) r['key'] as String: (r['value'] as String?) ?? ''};
  }
}
