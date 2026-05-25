import '../../core/services/database_service.dart';
import '../models/product_stock_movement.dart';

class ProductStockRepository {
  final _db = DatabaseService.instance;

  Future<void> record({
    required int productId,
    required int qtyDelta,
    required int qtyAfter,
    required String movementType,
    String? referenceType,
    int? referenceId,
    int? userId,
    String? note,
  }) async {
    await _db.insert('product_stock_movements', {
      'product_id': productId,
      'qty_delta': qtyDelta,
      'qty_after': qtyAfter,
      'movement_type': movementType,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'user_id': userId,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> deduct({
    required int productId,
    required int qty,
    required String movementType,
    String? referenceType,
    int? referenceId,
    int? userId,
    String? note,
  }) async {
    if (qty <= 0) return true;

    final rows = await _db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final current = (rows.first['current_qty'] as num?)?.toInt() ?? 0;
    if (current < qty) return false;

    final after = current - qty;
    await _db.update(
      'products',
      {'current_qty': after},
      where: 'id = ?',
      whereArgs: [productId],
    );
    await record(
      productId: productId,
      qtyDelta: -qty,
      qtyAfter: after,
      movementType: movementType,
      referenceType: referenceType,
      referenceId: referenceId,
      userId: userId,
      note: note,
    );
    return true;
  }

  Future<void> receive({
    required int productId,
    required int qty,
    int? userId,
    String? note,
  }) async {
    if (qty <= 0) return;

    final rows = await _db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final current = (rows.first['current_qty'] as num?)?.toInt() ?? 0;
    final after = current + qty;
    await _db.update(
      'products',
      {'current_qty': after},
      where: 'id = ?',
      whereArgs: [productId],
    );
    await record(
      productId: productId,
      qtyDelta: qty,
      qtyAfter: after,
      movementType: 'receive',
      userId: userId,
      note: note,
    );
  }

  Future<void> setQty({
    required int productId,
    required int newQty,
    int? userId,
    String? note,
  }) async {
    final rows = await _db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final current = (rows.first['current_qty'] as num?)?.toInt() ?? 0;
    final delta = newQty - current;
    if (delta == 0) return;

    await _db.update(
      'products',
      {'current_qty': newQty},
      where: 'id = ?',
      whereArgs: [productId],
    );
    await record(
      productId: productId,
      qtyDelta: delta,
      qtyAfter: newQty,
      movementType: 'adjustment',
      userId: userId,
      note: note,
    );
  }

  Future<List<ProductStockMovement>> listMovements({
    DateTime? from,
    DateTime? to,
    int? productId,
    int limit = 200,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (productId != null) {
      where.add('m.product_id = ?');
      args.add(productId);
    }
    if (from != null) {
      where.add('m.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('m.created_at <= ?');
      args.add(to.toIso8601String());
    }

    final sql = '''
      SELECT m.*, p.name AS product_name
      FROM product_stock_movements m
      INNER JOIN products p ON p.id = m.product_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY m.created_at DESC
      LIMIT $limit
    ''';

    final rows = await _db.raw(sql, args);
    return rows.map(ProductStockMovement.fromMap).toList();
  }

  Future<List<ProductStockSummary>> summaryForPeriod({
    required DateTime from,
    required DateTime to,
  }) async {
    final products = await _db.query('products', orderBy: 'name ASC');
    final rows = await _db.raw('''
      SELECT
        product_id,
        movement_type,
        SUM(CASE WHEN qty_delta > 0 THEN qty_delta ELSE 0 END) AS inbound,
        SUM(CASE WHEN qty_delta < 0 THEN -qty_delta ELSE 0 END) AS outbound
      FROM product_stock_movements
      WHERE created_at >= ? AND created_at <= ?
      GROUP BY product_id, movement_type
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final stats = <int, Map<String, int>>{};
    for (final row in rows) {
      final pid = row['product_id'] as int;
      final type = row['movement_type'] as String;
      final inbound = (row['inbound'] as num?)?.toInt() ?? 0;
      final outbound = (row['outbound'] as num?)?.toInt() ?? 0;
      stats.putIfAbsent(pid, () => {});
      stats[pid]![type] = inbound > 0 ? inbound : outbound;
    }

    return products.map((p) {
      final id = p['id'] as int;
      final s = stats[id] ?? {};
      return ProductStockSummary(
        productId: id,
        productName: p['name'] as String,
        currentQty: (p['current_qty'] as num?)?.toInt() ?? 0,
        received: s['receive'] ?? 0,
        sold: s['sale'] ?? 0,
        promoGiven: s['promo_reward'] ?? 0,
        adjusted: s['adjustment'] ?? 0,
      );
    }).toList();
  }
}
