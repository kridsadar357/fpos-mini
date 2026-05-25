import '../../core/services/database_service.dart';
import '../models/dispenser.dart';

class DispenserRepository {
  final _db = DatabaseService.instance;

  Future<List<Dispenser>> listAll() async {
    final rows = await _db.query('dispensers', orderBy: 'id ASC');
    return rows.map((r) => Dispenser.fromMap(r)).toList();
  }

  Future<List<Dispenser>> listActive() async {
    final rows = await _db.query('dispensers', where: 'is_active = 1');
    return rows.map((r) => Dispenser.fromMap(r)).toList();
  }

  Future<int> createDispenser(String name) async {
    return _db.insert('dispensers', {
      'name': name,
      'is_active': 1,
    });
  }

  Future<void> updateDispenser(
    int id, {
    String? name,
    bool? isActive,
  }) async {
    final data = <String, Object?>{};
    if (name != null) data['name'] = name;
    if (isActive != null) data['is_active'] = isActive ? 1 : 0;
    if (data.isEmpty) return;
    await _db.update('dispensers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDispenser(int id) async {
    await _db.delete('nozzles', where: 'dispenser_id = ?', whereArgs: [id]);
    await _db.delete('dispensers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createNozzle({
    required int dispenserId,
    required int tankId,
    required int nozzleNumber,
  }) async {
    return _db.insert('nozzles', {
      'dispenser_id': dispenserId,
      'tank_id': tankId,
      'nozzle_number': nozzleNumber,
    });
  }

  Future<void> updateNozzle(
    int id, {
    int? tankId,
    int? nozzleNumber,
  }) async {
    final data = <String, Object?>{};
    if (tankId != null) data['tank_id'] = tankId;
    if (nozzleNumber != null) data['nozzle_number'] = nozzleNumber;
    if (data.isEmpty) return;
    await _db.update('nozzles', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNozzle(int id) async {
    await _db.delete('nozzles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> listTanksForPicker() async {
    const sql = '''
      SELECT t.id, t.name, ft.name AS fuel_name
      FROM tanks t
      JOIN fuel_types ft ON t.fuel_type_id = ft.id
      ORDER BY t.id ASC
    ''';
    return _db.raw(sql);
  }

  Future<List<Nozzle>> listNozzles(int dispenserId) async {
    final rows = await _db
        .query('nozzles', where: 'dispenser_id = ?', whereArgs: [dispenserId]);
    return rows.map((r) => Nozzle.fromMap(r)).toList();
  }

  /// Returns nozzle with associated tank and fuel type info
  Future<List<Map<String, dynamic>>> getDetailedNozzles(int dispenserId) async {
    const sql = '''
      SELECT n.*, t.name as tank_name, ft.id as fuel_type_id, ft.name as fuel_name, ft.code as fuel_code, ft.color_hex, ft.price_per_liter
      FROM nozzles n
      JOIN tanks t ON n.tank_id = t.id
      JOIN fuel_types ft ON t.fuel_type_id = ft.id
      WHERE n.dispenser_id = ?
      ORDER BY n.nozzle_number ASC
    ''';
    return await _db.raw(sql, [dispenserId]);
  }

  Future<Map<int, int>> nozzleCountsByDispenser() async {
    const sql =
        'SELECT dispenser_id, COUNT(*) as c FROM nozzles GROUP BY dispenser_id';
    final rows = await _db.raw(sql);
    return {
      for (final r in rows)
        r['dispenser_id'] as int: (r['c'] as num).toInt(),
    };
  }
}
