import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/utils/money_utils.dart';
import 'package:fuel_pos/data/models/transaction.dart';
import 'package:fuel_pos/data/repositories/product_repository.dart';
import 'package:fuel_pos/data/repositories/tank_repository.dart';
import 'package:fuel_pos/data/repositories/transaction_repository.dart';

import 'helpers/test_database.dart';
import 'helpers/test_fixtures.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  tearDownAll(() async {
    await tearDownAllTestDatabase();
  });

  group('product cart sale', () {
    test('deducts product stock and records transaction', () async {
      final fx = await TestFixtures.seedPosStation();
      final productId = await TestFixtures.seedProduct(
        name: 'น้ำดื่ม',
        price: 15,
        qty: 10,
      );

      const qty = 2;
      const total = 30.0;

      final tx = await TransactionRepository().createProductCartSale(
        cashierId: fx.userId,
        shiftId: fx.shiftId,
        lines: [
          (
            productId: productId,
            name: 'น้ำดื่ม',
            price: 15,
            qty: qty,
          ),
        ],
        paymentMethod: 'CASH',
        total: total,
        received: total,
        changeAmount: 0,
      );

      expect(tx.total, 30);
      expect(tx.saleType, SaleType.product);

      final product = await ProductRepository().getById(productId);
      expect(product!.currentQty, 8);
    });

    test('insufficient stock rolls back product sale', () async {
      final fx = await TestFixtures.seedPosStation();
      final productId = await TestFixtures.seedProduct(qty: 1);

      expect(
        () => TransactionRepository().createProductCartSale(
          cashierId: fx.userId,
          shiftId: fx.shiftId,
          lines: [
            (
              productId: productId,
              name: 'Test Product',
              price: 15,
              qty: 3,
            ),
          ],
          paymentMethod: 'CASH',
          total: 45,
          received: 45,
          changeAmount: 0,
        ),
        throwsA(isA<StockInsufficientException>()),
      );

      final product = await ProductRepository().getById(productId);
      expect(product!.currentQty, 1);
    });
  });

  group('promo reward on fuel sale', () {
    test('deducts reward product stock when fuel sale includes promo gift', () async {
      final fx = await TestFixtures.seedPosStation(tankLiters: 5000);
      final productId = await TestFixtures.seedProduct(
        name: 'ผ้าเช็ด',
        price: 25,
        qty: 5,
      );
      final promoId = await TestFixtures.seedFreeProductPromo(
        productId: productId,
        fuelTypeId: fx.fuelTypeId,
        minAmount: 300,
        rewardQty: 1,
      );

      const liters = 10.0;
      final subtotal = MoneyUtils.fuelSubtotalFromLiters(
        liters: liters,
        pricePerLiter: fx.pricePerLiter,
      );

      final tx = await TransactionRepository().create(
        cashierId: fx.userId,
        shiftId: fx.shiftId,
        fuelTypeId: fx.fuelTypeId,
        nozzleId: fx.nozzleId,
        paymentMethod: 'CASH',
        liters: liters,
        pricePerLiter: fx.pricePerLiter,
        subtotal: subtotal,
        promotionId: promoId,
        total: subtotal,
        received: subtotal,
        changeAmount: 0,
        rewardProductId: productId,
        rewardQty: 1,
      );

      expect(tx.rewardProductId, productId);
      expect(tx.rewardQty, 1);

      final product = await ProductRepository().getById(productId);
      expect(product!.currentQty, 4);
    });

    test('rolls back fuel sale when reward product stock insufficient', () async {
      final fx = await TestFixtures.seedPosStation(tankLiters: 5000);
      final productId = await TestFixtures.seedProduct(qty: 0);

      const liters = 10.0;
      final subtotal = MoneyUtils.fuelSubtotalFromLiters(
        liters: liters,
        pricePerLiter: fx.pricePerLiter,
      );

      expect(
        () => TransactionRepository().create(
          cashierId: fx.userId,
          shiftId: fx.shiftId,
          fuelTypeId: fx.fuelTypeId,
          nozzleId: fx.nozzleId,
          paymentMethod: 'CASH',
          liters: liters,
          pricePerLiter: fx.pricePerLiter,
          subtotal: subtotal,
          total: subtotal,
          received: subtotal,
          changeAmount: 0,
          rewardProductId: productId,
          rewardQty: 1,
        ),
        throwsA(isA<StockInsufficientException>()),
      );

      final tank = await TankRepository().getById(fx.tankId);
      expect(tank!.currentLiters, closeTo(5000, 0.001));
    });
  });
}
