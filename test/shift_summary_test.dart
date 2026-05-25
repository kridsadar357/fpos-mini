import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/data/repositories/shift_repository.dart';
import 'package:fuel_pos/data/repositories/transaction_repository.dart';
import 'package:fuel_pos/core/utils/money_utils.dart';

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

  test('buildSummary aggregates payment methods and drawer cash', () async {
    final fx = await TestFixtures.seedPosStation(openingCash: 2000);
    const liters = 10.0;
    final subtotal = MoneyUtils.fuelSubtotalFromLiters(
      liters: liters,
      pricePerLiter: fx.pricePerLiter,
    );

    final txRepo = TransactionRepository();
    await txRepo.create(
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

    await txRepo.create(
      cashierId: fx.userId,
      shiftId: fx.shiftId,
      fuelTypeId: fx.fuelTypeId,
      nozzleId: fx.nozzleId,
      paymentMethod: 'QR',
      liters: 5,
      pricePerLiter: fx.pricePerLiter,
      subtotal: 160,
      total: 160,
      received: 160,
      changeAmount: 0,
    );

    final summary = await ShiftRepository().buildSummary(fx.shiftId);
    expect(summary, isNotNull);
    expect(summary!.saleCount, 2);
    expect(summary.totalSales, 320 + 160);
    expect(summary.byPayment['CASH'], 320);
    expect(summary.byPayment['QR'], 160);
    expect(summary.cashSalesTotal, 320);
    expect(summary.expectedDrawerCash, 2000 + 320);
  });
}
