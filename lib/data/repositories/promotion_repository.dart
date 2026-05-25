import '../../core/services/database_service.dart';
import '../models/promotion.dart';

class PromotionRepository {
  static const _selectSql = '''
    SELECT p.*, pr.name AS reward_product_name, pr.price AS reward_product_price
    FROM promotions p
    LEFT JOIN products pr ON p.reward_product_id = pr.id
  ''';

  Future<List<Promotion>> listAll() async {
    final rows = await DatabaseService.instance.raw(
      '$_selectSql ORDER BY p.is_active DESC, p.created_at DESC',
    );
    return rows.map(Promotion.fromMap).toList();
  }

  Future<List<Promotion>> listActive() async {
    final rows = await DatabaseService.instance.raw(
      '$_selectSql WHERE p.is_active = 1 ORDER BY p.created_at DESC',
    );
    return rows.map(Promotion.fromMap).toList();
  }

  Future<Promotion?> getById(int id) async {
    final rows = await DatabaseService.instance.raw(
      '$_selectSql WHERE p.id = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) return null;
    return Promotion.fromMap(rows.first);
  }

  /// Best-matching auto-applied promotion for a given fuel/subtotal.
  Future<Promotion?> findApplicable({
    required int fuelId,
    required double subtotal,
    required double liters,
  }) async {
    final actives = await listActive();
    Promotion? best;
    double bestValue = 0;
    for (final p in actives) {
      if (!p.appliesTo(fuelId: fuelId, subtotal: subtotal)) continue;
      final v = p.rankingValue(subtotal: subtotal, liters: liters);
      if (v > bestValue) {
        bestValue = v;
        best = p;
      }
    }
    return best;
  }

  Future<int> insert(Promotion p) =>
      DatabaseService.instance.insert('promotions', p.toMap()..remove('id'));

  Future<void> update(Promotion p) async {
    final map = p.toMap()..remove('id');
    await DatabaseService.instance.update(
      'promotions',
      map,
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> setActive(int id, bool active) =>
      DatabaseService.instance.update(
        'promotions',
        {'is_active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> delete(int id) =>
      DatabaseService.instance.delete('promotions', where: 'id = ?', whereArgs: [id]);
}

class DiscountRepository {
  Future<List<Discount>> listActive() async {
    final rows = await DatabaseService.instance
        .query('discounts', where: 'is_active = 1', orderBy: 'id ASC');
    return rows.map(Discount.fromMap).toList();
  }

  Future<int> insert({required String name, required String type, required double value}) {
    return DatabaseService.instance.insert('discounts', {
      'name': name,
      'type': type,
      'value': value,
      'is_active': 1,
    });
  }

  Future<void> setActive(int id, bool active) =>
      DatabaseService.instance.update(
        'discounts',
        {'is_active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
}
