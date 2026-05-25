import 'package:shared_preferences/shared_preferences.dart';

/// Fast splash routing without waiting on SQLite (avoids hang when DB open is slow).
class SplashInitCache {
  SplashInitCache._();

  static const _key = 'setup_complete_v1';

  static Future<bool?> readCached() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_key)) return null;
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> write(bool isInitialized) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isInitialized);
  }

  /// Cached value first; never block splash on SQLite (defaults to login screen).
  static Future<bool> resolveInitialized({
    Duration dbTimeout = const Duration(seconds: 2),
    required Future<bool> Function() readFromDatabase,
    Future<void> Function()? ensureDatabase,
  }) async {
    final cached = await readCached();
    if (cached != null) return cached;

    if (ensureDatabase == null) return true;

    try {
      await ensureDatabase().timeout(dbTimeout);
      final fromDb = await readFromDatabase().timeout(dbTimeout);
      await write(fromDb);
      return fromDb;
    } catch (_) {
      return true;
    }
  }
}
