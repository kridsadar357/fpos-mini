import '../../core/services/database_service.dart';
import '../models/shift.dart';
import '../models/shift_summary.dart';
import '../models/transaction.dart';

class ShiftRepository {
  final _db = DatabaseService.instance;

  Future<Shift?> getOpenShiftForUser(int userId) async {
    final rows = await _db.query(
      'shifts',
      where: "user_id = ? AND status = 'open'",
      whereArgs: [userId],
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shift.fromMap(rows.first);
  }

  Future<Shift> openShift({
    required int userId,
    double openingCash = 0,
  }) async {
    final existing = await getOpenShiftForUser(userId);
    if (existing != null) return existing;

    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('shifts', {
      'user_id': userId,
      'opened_at': now,
      'opening_cash': openingCash,
      'status': 'open',
    });

    await _db.audit(userId, 'shift_open', details: 'shift_id=$id');

    return Shift(
      id: id,
      userId: userId,
      openedAt: DateTime.parse(now),
      openingCash: openingCash,
      status: 'open',
    );
  }

  Future<void> closeShift({
    required int shiftId,
    required int userId,
    double? closingCash,
  }) async {
    await _db.update(
      'shifts',
      {
        'closed_at': DateTime.now().toIso8601String(),
        'closing_cash': closingCash,
        'status': 'closed',
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [shiftId, userId],
    );
    await _db.audit(userId, 'shift_close', details: 'shift_id=$shiftId');
  }

  Future<int> countSalesInShift(int shiftId) async {
    final rows = await _db.raw(
      'SELECT COUNT(*) as c FROM transactions WHERE shift_id = ?',
      [shiftId],
    );
    return rows.first['c'] as int? ?? 0;
  }

  Future<double> sumSalesInShift(int shiftId) async {
    final rows = await _db.raw(
      'SELECT COALESCE(SUM(total), 0) as s FROM transactions WHERE shift_id = ?',
      [shiftId],
    );
    return (rows.first['s'] as num?)?.toDouble() ?? 0;
  }

  Future<ShiftSummary?> buildSummary(int shiftId) async {
    final shift = await getById(shiftId);
    if (shift == null) return null;

    final totals = await _db.raw('''
      SELECT
        COUNT(*) AS c,
        COALESCE(SUM(total), 0) AS total,
        COALESCE(SUM(CASE WHEN sale_type = ? THEN total ELSE 0 END), 0) AS fuel_total,
        COALESCE(SUM(CASE WHEN sale_type = ? THEN total ELSE 0 END), 0) AS product_total,
        COALESCE(SUM(CASE WHEN sale_type = ? THEN liters ELSE 0 END), 0) AS liters,
        COALESCE(SUM(CASE WHEN sale_type = ? THEN 1 ELSE 0 END), 0) AS fuel_count,
        COALESCE(SUM(CASE WHEN sale_type = ? THEN 1 ELSE 0 END), 0) AS product_count,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN total ELSE 0 END), 0) AS cash_total
      FROM transactions
      WHERE shift_id = ?
    ''', [
      Transaction.saleTypeFuel,
      Transaction.saleTypeProduct,
      Transaction.saleTypeFuel,
      Transaction.saleTypeFuel,
      Transaction.saleTypeProduct,
      shiftId,
    ]);

    final row = totals.first;
    final paymentRows = await _db.raw('''
      SELECT payment_method, COALESCE(SUM(total), 0) AS s
      FROM transactions
      WHERE shift_id = ?
      GROUP BY payment_method
      ORDER BY s DESC
    ''', [shiftId]);

    final byPayment = <String, double>{};
    for (final p in paymentRows) {
      byPayment[p['payment_method'] as String] =
          (p['s'] as num?)?.toDouble() ?? 0;
    }

    return ShiftSummary(
      shift: shift,
      saleCount: row['c'] as int? ?? 0,
      totalSales: (row['total'] as num?)?.toDouble() ?? 0,
      fuelTotal: (row['fuel_total'] as num?)?.toDouble() ?? 0,
      productTotal: (row['product_total'] as num?)?.toDouble() ?? 0,
      liters: (row['liters'] as num?)?.toDouble() ?? 0,
      fuelCount: row['fuel_count'] as int? ?? 0,
      productCount: row['product_count'] as int? ?? 0,
      byPayment: byPayment,
      cashSalesTotal: (row['cash_total'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<Shift>> listByDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db.query(
      'shifts',
      where: 'opened_at >= ? AND opened_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'opened_at ASC',
    );
    return rows.map(Shift.fromMap).toList();
  }

  Future<Shift?> getById(int id) async {
    final rows = await _db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Shift.fromMap(rows.first);
  }
}
