import 'package:sqflite/sqflite.dart' as sqflite;

import '../../core/services/database_service.dart';
import '../../core/utils/money_utils.dart';
import '../models/shift.dart';
import '../models/transaction.dart';
import 'product_repository.dart';
import 'shift_repository.dart';

class StockInsufficientException implements Exception {
  final String productName;
  final int available;
  final int requested;

  StockInsufficientException({
    required this.productName,
    required this.available,
    required this.requested,
  });

  @override
  String toString() =>
      'สต็อก $productName ไม่พอ (มี $available ต้องการ $requested)';
}

class ShiftRequiredException implements Exception {
  @override
  String toString() => 'กรุณาเปิดกะก่อนทำรายการขาย';
}

class TankStockInsufficientException implements Exception {
  final double available;
  final double requested;

  TankStockInsufficientException({
    required this.available,
    required this.requested,
  });

  @override
  String toString() =>
      'สต็อกถังน้ำมันไม่พอ (มี ${available.toStringAsFixed(2)} L ต้องการ ${requested.toStringAsFixed(2)} L)';
}

class TransactionRepository {
  final _db = DatabaseService.instance;
  final _productRepo = ProductRepository();

  Future<void> _deductTankStockTxn(
    sqflite.Transaction txn, {
    required int tankId,
    required double liters,
  }) async {
    final rows = await txn.query(
      'tanks',
      where: 'id = ?',
      whereArgs: [tankId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('ไม่พบถัง id=$tankId');
    }

    final current = (rows.first['current_liters'] as num).toDouble();
    final newStock = current - liters;
    if (newStock < 0) {
      throw TankStockInsufficientException(
        available: current,
        requested: liters,
      );
    }

    await txn.update(
      'tanks',
      {'current_liters': newStock},
      where: 'id = ?',
      whereArgs: [tankId],
    );
  }

  Future<void> _deductProductStockTxn(
    sqflite.Transaction txn, {
    required int productId,
    required int qty,
    required String movementType,
    required String referenceType,
    required int referenceId,
    int? userId,
    String? note,
  }) async {
    final rows = await txn.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StockInsufficientException(
        productName: 'สินค้า',
        available: 0,
        requested: qty,
      );
    }

    final productName = rows.first['name'] as String;
    final current = (rows.first['current_qty'] as num?)?.toInt() ?? 0;
    if (current < qty) {
      throw StockInsufficientException(
        productName: productName,
        available: current,
        requested: qty,
      );
    }

    final after = current - qty;
    await txn.update(
      'products',
      {'current_qty': after},
      where: 'id = ?',
      whereArgs: [productId],
    );
    await txn.insert('product_stock_movements', {
      'product_id': productId,
      'qty_delta': -qty,
      'qty_after': after,
      'movement_type': movementType,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'user_id': userId,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _auditTxn(
    sqflite.Transaction txn,
    int? userId,
    String action, {
    String? details,
  }) async {
    await txn.insert('audit_log', {
      'user_id': userId,
      'action': action,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Transaction> create({
    required int cashierId,
    int? shiftId,
    required int fuelTypeId,
    int? dispenserId,
    int? nozzleId,
    required String paymentMethod,
    required double liters,
    required double pricePerLiter,
    required double subtotal,
    int? promotionId,
    double promotionAmount = 0,
    int? discountId,
    double discountAmount = 0,
    required double total,
    required double received,
    required double changeAmount,
    int? customerId,
    String? notes,
    int? rewardProductId,
    int rewardQty = 0,
  }) async {
    if (shiftId == null) {
      throw ShiftRequiredException();
    }

    if (rewardProductId != null && rewardQty > 0) {
      final product = await _productRepo.getById(rewardProductId);
      if (product == null || product.currentQty < rewardQty) {
        throw StockInsufficientException(
          productName: product?.name ?? 'สินค้า',
          available: product?.currentQty ?? 0,
          requested: rewardQty,
        );
      }
    }

    final normalizedSubtotal = MoneyUtils.ceilBaht(subtotal);
    final normalizedPromo = MoneyUtils.floorBaht(promotionAmount);
    final normalizedDiscount = MoneyUtils.floorBaht(discountAmount);
    final normalizedTotal = MoneyUtils.payableTotal(
      subtotal: normalizedSubtotal,
      promotionAmount: normalizedPromo,
      discountAmount: normalizedDiscount,
    );
    final normalizedReceived = MoneyUtils.ceilBaht(received);
    final normalizedChange = MoneyUtils.floorBaht(
      (normalizedReceived - normalizedTotal).clamp(0, double.infinity),
    );

    final now = DateTime.now();
    final receiptNo = 'TX-${now.millisecondsSinceEpoch}';

    return _db.runInTransaction((txn) async {
      final id = await txn.insert('transactions', {
        'receipt_no': receiptNo,
        'cashier_id': cashierId,
        'shift_id': shiftId,
        'fuel_type_id': fuelTypeId,
        'dispenser_id': dispenserId,
        'nozzle_id': nozzleId,
        'payment_method': paymentMethod,
        'liters': liters,
        'price_per_liter': pricePerLiter,
        'subtotal': normalizedSubtotal,
        'promotion_id': promotionId,
        'promotion_amount': normalizedPromo,
        'discount_id': discountId,
        'discount_amount': normalizedDiscount,
        'total': normalizedTotal,
        'received': normalizedReceived,
        'change_amount': normalizedChange,
        'printed': 0,
        'customer_id': customerId,
        'sale_type': Transaction.saleTypeFuel,
        'reward_product_id': rewardProductId,
        'reward_qty': rewardQty,
        'notes': notes,
        'created_at': now.toIso8601String(),
      });

      if (nozzleId != null) {
        final nozzleRows = await txn.query(
          'nozzles',
          where: 'id = ?',
          whereArgs: [nozzleId],
        );
        if (nozzleRows.isNotEmpty) {
          final tankId = nozzleRows.first['tank_id'] as int;
          await _deductTankStockTxn(txn, tankId: tankId, liters: liters);
        }
      }

      if (rewardProductId != null && rewardQty > 0) {
        await _deductProductStockTxn(
          txn,
          productId: rewardProductId,
          qty: rewardQty,
          movementType: 'promo_reward',
          referenceType: 'transaction',
          referenceId: id,
          userId: cashierId,
          note: notes,
        );
      }

      await _auditTxn(
        txn,
        cashierId,
        'sale',
        details: 'receipt=$receiptNo total=$normalizedTotal',
      );

      return Transaction(
        id: id,
        receiptNo: receiptNo,
        cashierId: cashierId,
        fuelTypeId: fuelTypeId,
        paymentMethod: paymentMethod,
        liters: liters,
        pricePerLiter: pricePerLiter,
        subtotal: normalizedSubtotal,
        promotionId: promotionId,
        promotionAmount: normalizedPromo,
        discountId: discountId,
        discountAmount: normalizedDiscount,
        total: normalizedTotal,
        received: normalizedReceived,
        changeAmount: normalizedChange,
        printed: false,
        customerId: customerId,
        shiftId: shiftId,
        rewardProductId: rewardProductId,
        rewardQty: rewardQty,
        notes: notes,
        saleType: SaleType.fuel,
        createdAt: now,
      );
    });
  }

  Future<Transaction> createProductSale({
    required int cashierId,
    int? shiftId,
    required int productId,
    required String productName,
    required double total,
    required String paymentMethod,
    double? received,
    double? changeAmount,
  }) async {
    return createProductCartSale(
      cashierId: cashierId,
      shiftId: shiftId,
      lines: [
        (productId: productId, name: productName, price: total, qty: 1),
      ],
      paymentMethod: paymentMethod,
      total: total,
      received: received ?? total,
      changeAmount: changeAmount ?? 0,
    );
  }

  Future<Transaction> createProductCartSale({
    required int cashierId,
    int? shiftId,
    required List<({
      int productId,
      String name,
      double price,
      int qty,
    })> lines,
    required String paymentMethod,
    required double total,
    required double received,
    required double changeAmount,
  }) async {
    if (shiftId == null) {
      throw ShiftRequiredException();
    }

    for (final line in lines) {
      final product = await _productRepo.getById(line.productId);
      if (product == null || product.currentQty < line.qty) {
        throw StockInsufficientException(
          productName: product?.name ?? line.name,
          available: product?.currentQty ?? 0,
          requested: line.qty,
        );
      }
    }

    final fuels = await _db.query('fuel_types', limit: 1);
    final fuelTypeId = fuels.isNotEmpty ? fuels.first['id'] as int : 1;
    final now = DateTime.now();
    final receiptNo = 'PD-${now.millisecondsSinceEpoch}';

    final normalizedTotal = MoneyUtils.ceilBaht(total);
    final normalizedReceived = MoneyUtils.ceilBaht(received);
    final normalizedChange = MoneyUtils.floorBaht(
      (normalizedReceived - normalizedTotal).clamp(0, double.infinity),
    );

    final body = lines
        .map((l) =>
            '${l.name} x${l.qty} = ${(l.price * l.qty).toStringAsFixed(2)}')
        .join('\n');
    final notes = 'สินค้า:\n$body';
    final productId = lines.length == 1 ? lines.first.productId : null;

    return _db.runInTransaction((txn) async {
      final id = await txn.insert('transactions', {
        'receipt_no': receiptNo,
        'cashier_id': cashierId,
        'shift_id': shiftId,
        'fuel_type_id': fuelTypeId,
        'payment_method': paymentMethod,
        'liters': 0,
        'price_per_liter': 0,
        'subtotal': normalizedTotal,
        'total': normalizedTotal,
        'received': normalizedReceived,
        'change_amount': normalizedChange,
        'printed': 0,
        'product_id': productId,
        'sale_type': Transaction.saleTypeProduct,
        'notes': notes,
        'created_at': now.toIso8601String(),
      });

      for (final line in lines) {
        await _deductProductStockTxn(
          txn,
          productId: line.productId,
          qty: line.qty,
          movementType: 'sale',
          referenceType: 'transaction',
          referenceId: id,
          userId: cashierId,
          note: line.name,
        );
      }

      await _auditTxn(
        txn,
        cashierId,
        'product_sale',
        details: 'items=${lines.length} total=$normalizedTotal',
      );

      return Transaction(
        id: id,
        receiptNo: receiptNo,
        cashierId: cashierId,
        fuelTypeId: fuelTypeId,
        paymentMethod: paymentMethod,
        liters: 0,
        pricePerLiter: 0,
        subtotal: normalizedTotal,
        total: normalizedTotal,
        received: normalizedReceived,
        changeAmount: normalizedChange,
        printed: false,
        notes: notes,
        saleType: SaleType.product,
        productId: productId,
        createdAt: now,
      );
    });
  }

  Future<Transaction?> getLastForCashier(int cashierId) async {
    final rows = await _db.query(
      'transactions',
      where: 'cashier_id = ?',
      whereArgs: [cashierId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Transaction.fromMap(rows.first);
  }

  Future<void> markPrinted(int id) async {
    await DatabaseService.instance.update(
      'transactions',
      {'printed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Transaction>> listByDate(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await DatabaseService.instance.query(
      'transactions',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> listBetween(DateTime from, DateTime to) async {
    final rows = await DatabaseService.instance.query(
      'transactions',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<SalesPeriodSummary> salesPeriodSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    final txs = await listBetween(start, end);

    double total = 0;
    double liters = 0;
    double fuelTotal = 0;
    double productTotal = 0;
    int fuelCount = 0;
    int productCount = 0;
    final byPayment = <String, double>{};
    final byFuel = <int, double>{};
    final byDay = <DateTime, DailySalesBucket>{};

    for (final t in txs) {
      total += t.total;
      byPayment[t.paymentMethod] = (byPayment[t.paymentMethod] ?? 0) + t.total;

      final dayKey = DateTime(
        t.createdAt.year,
        t.createdAt.month,
        t.createdAt.day,
      );
      final bucket = byDay.putIfAbsent(
        dayKey,
        () => DailySalesBucket(date: dayKey, total: 0, count: 0),
      );
      bucket.total += t.total;
      bucket.count++;

      if (t.isProductSale) {
        productTotal += t.total;
        productCount++;
      } else {
        fuelTotal += t.total;
        fuelCount++;
        liters += t.liters;
        byFuel[t.fuelTypeId] = (byFuel[t.fuelTypeId] ?? 0) + t.total;
      }
    }

    final dayList = byDay.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return SalesPeriodSummary(
      from: start,
      to: DateTime(to.year, to.month, to.day),
      count: txs.length,
      total: total,
      liters: liters,
      fuelCount: fuelCount,
      productCount: productCount,
      fuelTotal: fuelTotal,
      productTotal: productTotal,
      byPayment: byPayment,
      byFuel: byFuel,
      byDay: dayList,
      transactions: txs,
    );
  }

  Future<DailySummary> dailySummary(DateTime day) async {
    final txs = await listByDate(day);
    double total = 0;
    double liters = 0;
    double fuelTotal = 0;
    double productTotal = 0;
    int fuelCount = 0;
    int productCount = 0;
    final byPayment = <String, double>{};
    final byFuel = <int, double>{};
    for (final t in txs) {
      total += t.total;
      byPayment[t.paymentMethod] = (byPayment[t.paymentMethod] ?? 0) + t.total;
      if (t.isProductSale) {
        productTotal += t.total;
        productCount++;
      } else {
        fuelTotal += t.total;
        fuelCount++;
        liters += t.liters;
        byFuel[t.fuelTypeId] = (byFuel[t.fuelTypeId] ?? 0) + t.total;
      }
    }

    final shiftRepo = ShiftRepository();
    final shiftsOnDay = await shiftRepo.listByDate(day);
    final shiftMap = {for (final s in shiftsOnDay) s.id: s};
    final shiftIdsInTx = txs.map((t) => t.shiftId).whereType<int>().toSet();
    for (final id in shiftIdsInTx) {
      if (!shiftMap.containsKey(id)) {
        final s = await shiftRepo.getById(id);
        if (s != null) shiftMap[id] = s;
      }
    }

    final byShift = <ShiftDaySummary>[];
    final grouped = <int?, List<Transaction>>{};
    for (final t in txs) {
      grouped.putIfAbsent(t.shiftId, () => []).add(t);
    }

    for (final entry in grouped.entries) {
      final shiftTxs = entry.value;
      double sTotal = 0;
      double sFuel = 0;
      double sProduct = 0;
      double sLiters = 0;
      int sFuelCount = 0;
      int sProductCount = 0;
      final sPayment = <String, double>{};
      for (final t in shiftTxs) {
        sTotal += t.total;
        sPayment[t.paymentMethod] =
            (sPayment[t.paymentMethod] ?? 0) + t.total;
        if (t.isProductSale) {
          sProduct += t.total;
          sProductCount++;
        } else {
          sFuel += t.total;
          sFuelCount++;
          sLiters += t.liters;
        }
      }
      final shift = entry.key != null ? shiftMap[entry.key] : null;
      byShift.add(ShiftDaySummary(
        shiftId: entry.key,
        shift: shift,
        total: sTotal,
        fuelTotal: sFuel,
        productTotal: sProduct,
        liters: sLiters,
        fuelCount: sFuelCount,
        productCount: sProductCount,
        count: shiftTxs.length,
        byPayment: sPayment,
      ));
    }
    byShift.sort((a, b) {
      final ao = a.shift?.openedAt ?? DateTime(1970);
      final bo = b.shift?.openedAt ?? DateTime(1970);
      return ao.compareTo(bo);
    });

    return DailySummary(
      date: day,
      count: txs.length,
      total: total,
      liters: liters,
      fuelCount: fuelCount,
      productCount: productCount,
      fuelTotal: fuelTotal,
      productTotal: productTotal,
      byPayment: byPayment,
      byFuel: byFuel,
      byShift: byShift,
      transactions: txs,
    );
  }
}

class ShiftDaySummary {
  final int? shiftId;
  final Shift? shift;
  final double total;
  final double fuelTotal;
  final double productTotal;
  final double liters;
  final int fuelCount;
  final int productCount;
  final int count;
  final Map<String, double> byPayment;

  const ShiftDaySummary({
    this.shiftId,
    this.shift,
    required this.total,
    required this.fuelTotal,
    required this.productTotal,
    required this.liters,
    required this.fuelCount,
    required this.productCount,
    required this.count,
    required this.byPayment,
  });

  String label(int index) {
    if (shift != null) {
      final d = shift!.openedAt.toLocal();
      final time =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      return 'กะ #${shift!.id} · $time';
    }
    return 'ไม่ระบุกะ';
  }

  String get statusLabel {
    if (shift == null) return '—';
    return shift!.isOpen ? 'เปิดอยู่' : 'ปิดแล้ว';
  }
}

class DailySummary {
  final DateTime date;
  final int count;
  final double total;
  final double liters;
  final int fuelCount;
  final int productCount;
  final double fuelTotal;
  final double productTotal;
  final Map<String, double> byPayment;
  final Map<int, double> byFuel;
  final List<ShiftDaySummary> byShift;
  final List<Transaction> transactions;
  DailySummary({
    required this.date,
    required this.count,
    required this.total,
    required this.liters,
    this.fuelCount = 0,
    this.productCount = 0,
    this.fuelTotal = 0,
    this.productTotal = 0,
    required this.byPayment,
    required this.byFuel,
    this.byShift = const [],
    required this.transactions,
  });
}

class DailySalesBucket {
  double total;
  int count;
  final DateTime date;

  DailySalesBucket({
    required this.date,
    required this.total,
    required this.count,
  });
}

class SalesPeriodSummary {
  final DateTime from;
  final DateTime to;
  final int count;
  final double total;
  final double liters;
  final int fuelCount;
  final int productCount;
  final double fuelTotal;
  final double productTotal;
  final Map<String, double> byPayment;
  final Map<int, double> byFuel;
  final List<DailySalesBucket> byDay;
  final List<Transaction> transactions;

  const SalesPeriodSummary({
    required this.from,
    required this.to,
    required this.count,
    required this.total,
    required this.liters,
    this.fuelCount = 0,
    this.productCount = 0,
    this.fuelTotal = 0,
    this.productTotal = 0,
    required this.byPayment,
    required this.byFuel,
    required this.byDay,
    required this.transactions,
  });
}
