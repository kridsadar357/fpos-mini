import '../../core/services/database_service.dart';
import '../models/user.dart';

class AuthRepository {
  Future<AppUser?> getById(int id) async {
    final rows = await DatabaseService.instance.query(
      'users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> login(String username, String password) async {
    final rows = await DatabaseService.instance.query(
      'users',
      where:
          'LOWER(username) = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [
        username.trim().toLowerCase(),
        DatabaseService.hash(password),
      ],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = AppUser.fromMap(rows.first);
    DatabaseService.instance.audit(user.id, 'login');
    return user;
  }

  Future<List<AppUser>> list() async {
    final rows = await DatabaseService.instance.query(
      'users',
      orderBy: 'username ASC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  Future<void> create({
    required String username,
    required String password,
    required String role,
    String? displayName,
  }) async {
    await DatabaseService.instance.insert('users', {
      'username': username.trim(),
      'password_hash': DatabaseService.hash(password),
      'role': role,
      'display_name': displayName,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setActive(int id, bool active) async {
    await DatabaseService.instance.update(
      'users',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> changePassword(int id, String newPassword) async {
    await DatabaseService.instance.update(
      'users',
      {'password_hash': DatabaseService.hash(newPassword)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
