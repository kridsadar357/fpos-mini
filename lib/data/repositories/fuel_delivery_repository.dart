import '../../core/services/database_service.dart';
import '../models/fuel_delivery.dart';
import '../models/fuel_import_line.dart';
import '../models/fuel_import_profit.dart';
import 'supplier_repository.dart';
import 'tank_repository.dart';

class FuelDeliveryRepository {
  final _db = DatabaseService.instance;
  final _tanks = TankRepository();
  final _suppliers = SupplierRepository();

  static const _listSql = '''
      SELECT d.*,
             s.name AS supplier_name,
             t.name AS tank_name,
             t.fuel_type_id AS fuel_type_id,
             ft.name AS fuel_name,
             ft.price_per_liter AS sell_price,
             u.username
      FROM fuel_deliveries d
      JOIN suppliers s ON s.id = d.supplier_id
      JOIN tanks t ON t.id = d.tank_id
      JOIN fuel_types ft ON ft.id = t.fuel_type_id
      LEFT JOIN users u ON u.id = d.user_id
    ''';

  Future<String> recordBatchImport({
    required int supplierId,
    required List<FuelImportLine> lines,
    int? userId,
    String? orderNote,
    double? shippingCost,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('lines must not be empty');
    }

    final supplier = await _suppliers.getById(supplierId);
    final snapshot = supplier?.encodeSnapshot();
    final batchAt = DateTime.now().toIso8601String();
    final batchKey = '${DateTime.now().millisecondsSinceEpoch}_$supplierId';
    final ids = <int>[];

    for (final line in lines) {
      if (line.liters <= 0) {
        throw ArgumentError('liters must be positive');
      }
      final id = await _db.insert('fuel_deliveries', {
        'supplier_id': supplierId,
        'tank_id': line.tankId,
        'liters': line.liters,
        'unit_cost': line.unitCost,
        'shipping_cost': shippingCost,
        'note': orderNote,
        'supplier_snapshot': snapshot,
        'batch_key': batchKey,
        'status': FuelImportBatch.statusPending,
        'received_liters': null,
        'user_id': userId,
        'created_at': batchAt,
      });
      ids.add(id);
    }

    final litersSummary =
        lines.map((l) => 't${l.tankId}:${l.liters}').join(',');
    await _db.audit(
      userId,
      'fuel_import',
      details:
          'order batch=$batchKey supplier_id=$supplierId lines=${lines.length} [$litersSummary]',
    );

    return batchKey;
  }

  Future<void> confirmReceipt({
    required String batchKey,
    required Map<int, double> receivedByDeliveryId,
    int? userId,
  }) async {
    final batch = await getBatch(batchKey);
    if (batch == null) throw StateError('batch not found');
    if (batch.isReceived) throw StateError('already received');

    final receipts = <({int deliveryId, int tankId, double received, double newStock})>[];
    for (final line in batch.lines) {
      final received = receivedByDeliveryId[line.id] ?? line.orderedLiters;
      if (received <= 0) {
        throw ArgumentError('received liters must be positive');
      }
      final tank = await _tanks.getById(line.tankId);
      if (tank == null) {
        throw StateError('ไม่พบถังสำหรับ ${line.tankName}');
      }
      if (!tank.canReceive(received)) {
        throw StateError(
          '${tank.name} (${line.fuelName ?? line.tankName}): '
          'รับ ${received.toStringAsFixed(2)} L เกินความจุ — '
          'คงเหลือว่าง ${tank.availableLiters.toStringAsFixed(2)} L '
          'จาก ${tank.capacity.toStringAsFixed(2)} L',
        );
      }
      receipts.add((
        deliveryId: line.id,
        tankId: line.tankId,
        received: received,
        newStock: tank.currentLiters + received,
      ));
    }

    await _db.runInTransaction((txn) async {
      for (final r in receipts) {
        await txn.update(
          'tanks',
          {'current_liters': r.newStock},
          where: 'id = ?',
          whereArgs: [r.tankId],
        );
        await txn.update(
          'fuel_deliveries',
          {
            'received_liters': r.received,
            'status': FuelImportBatch.statusReceived,
          },
          where: 'id = ?',
          whereArgs: [r.deliveryId],
        );
      }
      await txn.insert('audit_log', {
        'user_id': userId,
        'action': 'fuel_import',
        'details': 'receive batch=$batchKey lines=${receipts.length}',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<FuelDelivery>> listRecent({int limit = 200}) async {
    const sql = '''
      $_listSql
      ORDER BY d.created_at DESC, d.id DESC
      LIMIT ?
    ''';
    final rows = await _db.raw(sql, [limit]);
    return rows.map((r) => FuelDelivery.fromMap(r)).toList();
  }

  List<FuelImportBatch> _groupDeliveries(List<FuelDelivery> deliveries) {
    final grouped = <String, List<FuelDelivery>>{};
    final order = <String>[];

    for (final d in deliveries) {
      final key = d.batchKey.isNotEmpty
          ? d.batchKey
          : '${d.supplierId}_${d.createdAt.toIso8601String()}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        order.add(key);
      }
      grouped[key]!.add(d);
    }

    return order.map((key) {
      final items = grouped[key]!;
      final first = items.first;
      final status = items.any((e) => e.status == FuelImportBatch.statusPending)
          ? FuelImportBatch.statusPending
          : FuelImportBatch.statusReceived;
      return FuelImportBatch(
        batchKey: key,
        supplierId: first.supplierId,
        supplierName: first.supplierName,
        supplierSnapshot: first.supplierSnapshot,
        createdAt: first.createdAt,
        orderNote: first.note,
        shippingCost: first.shippingCost,
        status: status,
        lines: items.map((d) => d.asLine).toList(),
      );
    }).toList();
  }

  Future<List<FuelImportBatch>> listAllBatches({int limit = 100}) async {
    final deliveries = await listRecent(limit: limit * 8);
    final batches = _groupDeliveries(deliveries);
    return batches.take(limit).toList();
  }

  Future<List<FuelImportBatch>> listRecentBatches({int limit = 30}) =>
      listAllBatches(limit: limit);

  Future<FuelImportBatch?> getBatch(String batchKey) async {
    const sql = '''
      $_listSql
      WHERE d.batch_key = ?
      ORDER BY d.id ASC
    ''';
    final rows = await _db.raw(sql, [batchKey]);
    if (rows.isEmpty) return null;
    final deliveries = rows.map((r) => FuelDelivery.fromMap(r)).toList();
    return _groupDeliveries(deliveries).firstOrNull;
  }

  Future<List<FuelImportProfitRow>> computeProfit(String batchKey) async {
    final batch = await getBatch(batchKey);
    if (batch == null) return [];

    final allBatches = await listAllBatches(limit: 200);
    final currentIdx = allBatches.indexWhere((b) => b.batchKey == batchKey);
    FuelImportBatch? previousBatch;
    if (currentIdx >= 0 && currentIdx + 1 < allBatches.length) {
      previousBatch = allBatches[currentIdx + 1];
    }

    final rows = <FuelImportProfitRow>[];
    final totalLiters = batch.totalOrderedLiters;
    final shippingPerLiter = batch.shippingCost != null && totalLiters > 0
        ? batch.shippingCost! / totalLiters
        : null;

    for (final line in batch.lines) {
      double? prevCost;
      if (previousBatch != null) {
        for (final prev in previousBatch.lines) {
          if (prev.fuelTypeId == line.fuelTypeId && prev.unitCost != null) {
            prevCost = prev.unitCost;
            break;
          }
        }
      }

      final sellRows = await _db.raw(
        'SELECT price_per_liter FROM fuel_types WHERE id = ? LIMIT 1',
        [line.fuelTypeId],
      );
      final sellPrice = sellRows.isNotEmpty
          ? (sellRows.first['price_per_liter'] as num?)?.toDouble() ?? 0.0
          : 0.0;

      rows.add(FuelImportProfitRow(
        fuelName: line.fuelName ?? line.tankName,
        fuelTypeId: line.fuelTypeId,
        previousUnitCost: prevCost,
        currentUnitCost: line.unitCost,
        shippingPerLiter: shippingPerLiter,
        sellPricePerLiter: sellPrice,
        orderedLiters: line.receivedLiters ?? line.orderedLiters,
      ));
    }
    return rows;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
