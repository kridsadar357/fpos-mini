import '../../core/services/database_service.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final _db = DatabaseService.instance;

  Future<List<Supplier>> listActive() async {
    final rows = await _db.query(
      'suppliers',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  Future<List<Supplier>> listAll() async {
    final rows = await _db.query('suppliers', orderBy: 'name ASC');
    return rows.map((r) => Supplier.fromMap(r)).toList();
  }

  Future<Supplier?> getById(int id) async {
    final rows = await _db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  Future<int> create(Supplier supplier) async {
    return _db.insert('suppliers', supplier.toMap());
  }

  Future<void> update(Supplier supplier) async {
    if (supplier.id == null) return;
    await _db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }
}
