import '../../core/services/database_service.dart';
import '../models/fuel_type.dart';

class FuelRepository {
  Future<List<FuelType>> listActive() async {
    final rows = await DatabaseService.instance.query(
      'fuel_types',
      where: 'is_active = 1',
      orderBy: 'id ASC',
    );
    return rows.map(FuelType.fromMap).toList();
  }

  Future<List<FuelType>> listAll() async {
    final rows = await DatabaseService.instance.query(
      'fuel_types',
      orderBy: 'id ASC',
    );
    return rows.map(FuelType.fromMap).toList();
  }

  Future<FuelType?> getById(int id) async {
    final rows = await DatabaseService.instance.query(
      'fuel_types',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FuelType.fromMap(rows.first);
  }

  Future<void> updatePrice(int id, double price) async {
    await DatabaseService.instance.update(
      'fuel_types',
      {'price_per_liter': price},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setActive(int id, bool active) async {
    await DatabaseService.instance.update(
      'fuel_types',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
