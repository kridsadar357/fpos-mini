import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/services/database_service.dart';
import 'package:fuel_pos/core/utils/money_utils.dart';
import 'package:fuel_pos/data/repositories/shift_repository.dart';
import 'package:fuel_pos/data/repositories/tank_repository.dart';
import 'package:fuel_pos/data/repositories/transaction_repository.dart';

import 'helpers/test_database.dart';
import 'helpers/test_fixtures.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  tearDownAll(() async {
    await tearDownAllTestDatabase();
  });

  group('sale → shift summary → close shift', () {
    test('fuel sale ceils baht, updates summary, deducts tank stock', () async {
      final fx = await TestFixtures.seedPosStation();
      const liters = 10.0;
      final subtotal = MoneyUtils.fuelSubtotalFromLiters(
        liters: liters,
        pricePerLiter: fx.pricePerLiter,
      );

      expect(subtotal, 320);

      final txRepo = TransactionRepository();
      final tx = await txRepo.create(
        cashierId: fx.userId,
        shiftId: fx.shiftId,
        fuelTypeId: fx.fuelTypeId,
        nozzleId: fx.nozzleId,
        paymentMethod: 'CASH',
        liters: liters,
        pricePerLiter: fx.pricePerLiter,
        subtotal: subtotal,
        total: subtotal,
        received: 500,
        changeAmount: 500 - subtotal,
      );

      expect(tx.subtotal, 320);
      expect(tx.total, 320);
      expect(MoneyUtils.isWholeBaht(tx.total), isTrue);
      expect(MoneyUtils.isWholeBaht(tx.changeAmount), isTrue);

      final summary = await ShiftRepository().buildSummary(fx.shiftId);
      expect(summary, isNotNull);
      expect(summary!.saleCount, 1);
      expect(summary.totalSales, 320);
      expect(summary.fuelCount, 1);
      expect(summary.liters, liters);
      expect(summary.cashSalesTotal, 320);
      expect(summary.expectedDrawerCash, 1000 + 320);

      final tank = await TankRepository().getById(fx.tankId);
      expect(tank!.currentLiters, closeTo(4990, 0.001));
    });

    test('close shift marks shift closed and keeps sale totals', () async {
      final fx = await TestFixtures.seedPosStation();
      const liters = 5.0;
      final subtotal = MoneyUtils.fuelSubtotalFromLiters(
        liters: liters,
        pricePerLiter: fx.pricePerLiter,
      );

      await TransactionRepository().create(
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
      );

      final shiftRepo = ShiftRepository();
      final beforeClose = await shiftRepo.buildSummary(fx.shiftId);
      expect(beforeClose!.shift.isOpen, isTrue);

      await shiftRepo.closeShift(
        shiftId: fx.shiftId,
        userId: fx.userId,
        closingCash: beforeClose.expectedDrawerCash,
      );

      final closed = await shiftRepo.getById(fx.shiftId);
      expect(closed!.isOpen, isFalse);
      expect(closed.closingCash, beforeClose.expectedDrawerCash);
      expect(await shiftRepo.getOpenShiftForUser(fx.userId), isNull);

      final afterClose = await shiftRepo.buildSummary(fx.shiftId);
      expect(afterClose!.saleCount, beforeClose.saleCount);
      expect(afterClose.totalSales, beforeClose.totalSales);
    });

    test('insufficient tank stock rolls back transaction', () async {
      final fx = await TestFixtures.seedPosStation(tankLiters: 3);
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
        ),
        throwsA(isA<TankStockInsufficientException>()),
      );

      expect(await ShiftRepository().countSalesInShift(fx.shiftId), 0);

      final tank = await TankRepository().getById(fx.tankId);
      expect(tank!.currentLiters, 3);
    });

    test('sale without shift throws ShiftRequiredException', () async {
      final fx = await TestFixtures.seedPosStation();

      expect(
        () => TransactionRepository().create(
          cashierId: fx.userId,
          shiftId: null,
          fuelTypeId: fx.fuelTypeId,
          nozzleId: fx.nozzleId,
          paymentMethod: 'CASH',
          liters: 1,
          pricePerLiter: fx.pricePerLiter,
          subtotal: 32,
          total: 32,
          received: 32,
          changeAmount: 0,
        ),
        throwsA(isA<ShiftRequiredException>()),
      );
    });
  });

  group('startup health', () {
    test('startupHealthCheck passes on fresh test database', () async {
      final health = await DatabaseService.instance.startupHealthCheck();
      expect(health.ok, isTrue);
    });
  });
}
