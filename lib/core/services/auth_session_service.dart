import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/shift.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import 'database_service.dart';

/// จำผู้ใช้ + กะที่เปิดอยู่ ระหว่างเปิดแอป
class AuthSessionService {
  AuthSessionService._();
  static final AuthSessionService instance = AuthSessionService._();

  static const _keyUsername = 'session_username';
  static const _keyUserId = 'session_user_id';
  static const _keyShiftId = 'session_shift_id';
  static const _keyRemember = 'remember_username';

  Future<void> saveSession({
    required String username,
    required int userId,
    required int shiftId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyUsername, username);
    await p.setInt(_keyUserId, userId);
    await p.setInt(_keyShiftId, shiftId);
  }

  Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyUserId);
    await p.remove(_keyShiftId);
  }

  Future<void> clearShiftId() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyShiftId);
  }

  Future<void> updateShiftId(int shiftId) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyShiftId, shiftId);
  }

  Future<({String? username, int? userId, int? shiftId})> loadSession() async {
    final p = await SharedPreferences.getInstance();
    return (
      username: p.getString(_keyUsername),
      userId: p.getInt(_keyUserId),
      shiftId: p.getInt(_keyShiftId),
    );
  }

  Future<void> setRememberUsername(bool remember, String username) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyRemember, remember);
    if (remember) {
      await p.setString(_keyUsername, username);
    } else {
      await p.remove(_keyUsername);
    }
  }

  Future<bool> rememberUsernameEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyRemember) ?? true;
  }

  Future<String?> rememberedUsername() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_keyRemember) ?? true)) return null;
    return p.getString(_keyUsername);
  }

  /// คืนค่า user+shift ถ้ายังมีกะเปิดอยู่ (ใช้ตอนเปิดแอป)
  Future<({AppUser user, Shift shift})?> tryRestoreLogin() async {
    final s = await loadSession();
    if (s.userId == null || s.shiftId == null) return null;

    final user = await AuthRepository().getById(s.userId!);
    if (user == null) {
      await clearSession();
      return null;
    }

    final rows = await DatabaseService.instance.query(
      'shifts',
      where: "id = ? AND user_id = ? AND status = 'open'",
      whereArgs: [s.shiftId, user.id],
      limit: 1,
    );
    if (rows.isEmpty) {
      await clearSession();
      return null;
    }

    return (user: user, shift: Shift.fromMap(rows.first));
  }
}
