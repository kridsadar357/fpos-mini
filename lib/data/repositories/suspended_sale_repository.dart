import 'dart:convert';

import '../../core/services/database_service.dart';

class SuspendedSale {
  final int id;
  final int cashierId;
  final Map<String, dynamic> payload;
  final String? note;
  final DateTime createdAt;

  SuspendedSale({
    required this.id,
    required this.cashierId,
    required this.payload,
    this.note,
    required this.createdAt,
  });

  String get label {
    final fuel = payload['fuel_name'] ?? 'รายการ';
    final amount = payload['subtotal'] ?? payload['fuel_amount'] ?? 0;
    return '$fuel — ฿$amount';
  }
}

class SuspendedSaleRepository {
  final _db = DatabaseService.instance;

  Future<int> save({
    required int cashierId,
    required Map<String, dynamic> payload,
    String? note,
  }) async {
    return _db.insert('suspended_sales', {
      'cashier_id': cashierId,
      'payload': jsonEncode(payload),
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<SuspendedSale>> listActive() async {
    final rows = await _db.query(
      'suspended_sales',
      orderBy: 'created_at DESC',
      limit: 50,
    );
    return rows
        .map((r) => SuspendedSale(
              id: r['id'] as int,
              cashierId: r['cashier_id'] as int,
              payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
              note: r['note'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();
  }

  Future<void> delete(int id) async {
    await _db.delete('suspended_sales', where: 'id = ?', whereArgs: [id]);
  }
}
