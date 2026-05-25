import '../../core/services/database_service.dart';
import '../models/tank.dart';
import '../models/tank_daily_usage.dart';

class TankRepository {
  final _db = DatabaseService.instance;

  Future<List<Tank>> listAll() async {
    const sql = '''
      SELECT t.*, ft.name AS fuel_name, ft.color_hex
      FROM tanks t
      JOIN fuel_types ft ON t.fuel_type_id = ft.id
      ORDER BY t.id ASC
    ''';
    final rows = await _db.raw(sql);
    return rows.map((r) => Tank.fromMap(r)).toList();
  }

  Future<Tank?> getById(int id) async {
    final rows = await _db.query('tanks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Tank.fromMap(rows.first);
  }

  Future<Tank?> getByFuelType(int fuelTypeId) async {
    final rows = await _db.query('tanks', where: 'fuel_type_id = ?', whereArgs: [fuelTypeId], limit: 1);
    if (rows.isEmpty) return null;
    return Tank.fromMap(rows.first);
  }

  Future<void> updateStock(int tankId, double newLiters) async {
    await _db.update(
      'tanks',
      {'current_liters': newLiters},
      where: 'id = ?',
      whereArgs: [tankId],
    );
  }

  /// Manual stock adjustment with audit trail (atomic).
  Future<void> manualAdjustStock({
    required int tankId,
    required double newLiters,
    int? userId,
    String? note,
  }) async {
    await _db.runInTransaction((txn) async {
      final rows = await txn.query(
        'tanks',
        where: 'id = ?',
        whereArgs: [tankId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('ไม่พบถัง id=$tankId');
      final tank = Tank.fromMap(rows.first);
      if (newLiters < 0 || newLiters > tank.capacity + 0.001) {
        throw ArgumentError(
          'ยอดต้องอยู่ระหว่าง 0 – ${tank.capacity.toStringAsFixed(2)} L',
        );
      }
      final before = tank.currentLiters;
      await txn.update(
        'tanks',
        {'current_liters': newLiters},
        where: 'id = ?',
        whereArgs: [tankId],
      );
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'tank_manual_adjust',
        'details':
            'tank_id=$tankId ${before.toStringAsFixed(2)}→${newLiters.toStringAsFixed(2)}'
            '${note != null && note.isNotEmpty ? ' note=$note' : ''}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Deducts stock from a tank. Returns true if successful.
  Future<bool> deductStock(int tankId, double litersToDeduct) async {
    final tank = await getById(tankId);
    if (tank == null) return false;

    final newStock = tank.currentLiters - litersToDeduct;
    if (newStock < 0) return false; // Prevent negative stock

    await updateStock(tankId, newStock);
    return true;
  }

  Future<void> refill(int tankId, double litersToAdd) async {
    final tank = await getById(tankId);
    if (tank == null) throw StateError('ไม่พบถัง id=$tankId');
    if (!tank.canReceive(litersToAdd)) {
      throw StateError(
        '${tank.name}: รับ ${litersToAdd.toStringAsFixed(2)} L เกินความจุ '
        '(ว่าง ${tank.availableLiters.toStringAsFixed(2)} / ${tank.capacity.toStringAsFixed(2)} L)',
      );
    }
    await updateStock(tankId, tank.currentLiters + litersToAdd);
  }

  /// สรุปขาย/รับรายวันย้อนหลัง (สำหรับกราฟคลังน้ำมัน)
  Future<List<TankDailyUsage>> dailyUsage(int tankId, {int days = 7}) async {
    final count = days.clamp(1, 30);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: count - 1));
    final startIso = start.toIso8601String();

    final soldRows = await _db.raw('''
      SELECT date(t.created_at) AS day, SUM(t.liters) AS liters
      FROM transactions t
      INNER JOIN nozzles n ON n.id = t.nozzle_id
      WHERE n.tank_id = ?
        AND t.sale_type = 'fuel'
        AND date(t.created_at) >= date(?)
      GROUP BY date(t.created_at)
    ''', [tankId, startIso]);

    final recvRows = await _db.raw('''
      SELECT date(created_at) AS day,
             SUM(COALESCE(received_liters, liters)) AS liters
      FROM fuel_deliveries
      WHERE tank_id = ?
        AND status = 'received'
        AND date(created_at) >= date(?)
      GROUP BY date(created_at)
    ''', [tankId, startIso]);

    final soldByDay = <String, double>{};
    for (final row in soldRows) {
      soldByDay[row['day'] as String] = (row['liters'] as num).toDouble();
    }

    final recvByDay = <String, double>{};
    for (final row in recvRows) {
      recvByDay[row['day'] as String] = (row['liters'] as num).toDouble();
    }

    return List.generate(count, (i) {
      final day = start.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return TankDailyUsage(
        day: day,
        soldLiters: soldByDay[key] ?? 0,
        receivedLiters: recvByDay[key] ?? 0,
      );
    });
  }
}
