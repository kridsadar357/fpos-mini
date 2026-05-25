import '../../core/services/database_service.dart';
import '../models/product.dart';
import 'product_stock_repository.dart';

class ProductRepository {
  final _db = DatabaseService.instance;
  final _stock = ProductStockRepository();

  Future<List<Product>> listAll() async {
    final rows = await _db.query('products', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(int id) async {
    final rows = await _db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> listActive() async {
    final rows = await _db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<int> create({
    required String name,
    required double price,
    String? sku,
    String? imagePath,
    int initialQty = 0,
    int? userId,
  }) async {
    final id = await _db.insert('products', {
      'name': name,
      'price': price,
      'sku': sku,
      'image_path': imagePath,
      'current_qty': initialQty,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    if (initialQty > 0) {
      await _stock.record(
        productId: id,
        qtyDelta: initialQty,
        qtyAfter: initialQty,
        movementType: 'receive',
        userId: userId,
        note: 'สต็อกเริ่มต้น',
      );
    }
    return id;
  }

  Future<void> update({
    required int id,
    required String name,
    required double price,
    String? sku,
    String? imagePath,
    bool clearImage = false,
  }) async {
    final data = <String, Object?>{
      'name': name,
      'price': price,
      'sku': sku,
    };
    if (clearImage) {
      data['image_path'] = null;
    } else if (imagePath != null) {
      data['image_path'] = imagePath;
    }
    await _db.update(
      'products',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateImagePath(int id, String? imagePath) async {
    await _db.update(
      'products',
      {'image_path': imagePath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setActive(int id, bool active) async {
    await _db.update(
      'products',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
