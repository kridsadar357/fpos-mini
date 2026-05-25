import 'package:fuel_pos/core/services/database_service.dart';

class TestFixtures {
  static Future<
      ({
        int userId,
        int shiftId,
        int nozzleId,
        int fuelTypeId,
        int tankId,
        double pricePerLiter,
      })> seedPosStation({
    double openingCash = 1000,
    double tankLiters = 5000,
  }) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();

    final userId = await db.insert('users', {
      'username': 'testcashier_${now.hashCode}',
      'password_hash': DatabaseService.hash('test123'),
      'role': 'cashier',
      'display_name': 'Test Cashier',
      'is_active': 1,
      'created_at': now,
    });

    const fuelTypeId = 1;
    const pricePerLiter = 31.94;

    final tankId = await db.insert('tanks', {
      'name': 'Test Tank B7',
      'fuel_type_id': fuelTypeId,
      'capacity': 10000,
      'current_liters': tankLiters,
    });

    final dispenserId = await db.insert('dispensers', {
      'name': 'Test Pump',
      'is_active': 1,
    });

    final nozzleId = await db.insert('nozzles', {
      'dispenser_id': dispenserId,
      'tank_id': tankId,
      'nozzle_number': 1,
    });

    final shiftId = await db.insert('shifts', {
      'user_id': userId,
      'opened_at': now,
      'opening_cash': openingCash,
      'status': 'open',
    });

    return (
      userId: userId,
      shiftId: shiftId,
      nozzleId: nozzleId,
      fuelTypeId: fuelTypeId,
      tankId: tankId,
      pricePerLiter: pricePerLiter,
    );
  }

  static Future<int> seedSupplier({String name = 'Test Supplier'}) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    return db.insert('suppliers', {
      'name': name,
      'is_active': 1,
      'created_at': now,
    });
  }

  static Future<int> seedProduct({
    String name = 'Test Product',
    double price = 15,
    int qty = 10,
  }) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    return db.insert('products', {
      'name': name,
      'price': price,
      'current_qty': qty,
      'is_active': 1,
      'created_at': now,
    });
  }

  static Future<int> seedFreeProductPromo({
    required int productId,
    required int fuelTypeId,
    double minAmount = 300,
    int rewardQty = 1,
  }) async {
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    return db.insert('promotions', {
      'name': 'แถมสินค้าทดสอบ',
      'type': 'free_product',
      'value': 0,
      'min_amount': minAmount,
      'fuel_type_id': fuelTypeId,
      'reward_product_id': productId,
      'reward_qty': rewardQty,
      'is_active': 1,
      'created_at': now,
    });
  }

  static Future<int> seedSecondTank({
    required int fuelTypeId,
    double capacity = 10000,
    double currentLiters = 5000,
  }) async {
    final db = DatabaseService.instance;
    return db.insert('tanks', {
      'name': 'Test Tank 2',
      'fuel_type_id': fuelTypeId,
      'capacity': capacity,
      'current_liters': currentLiters,
    });
  }
}
