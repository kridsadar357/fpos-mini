import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/data/models/fuel_import_line.dart';
import 'package:fuel_pos/data/repositories/fuel_delivery_repository.dart';
import 'package:fuel_pos/data/repositories/tank_repository.dart';

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

  group('fuel import confirmReceipt', () {
    test('increases tank stock atomically on receive', () async {
      final fx = await TestFixtures.seedPosStation(tankLiters: 4000);
      final supplierId = await TestFixtures.seedSupplier();
      const receiveLiters = 500.0;

      final repo = FuelDeliveryRepository();
      final batchKey = await repo.recordBatchImport(
        supplierId: supplierId,
        userId: fx.userId,
        lines: [
          FuelImportLine(
            tankId: fx.tankId,
            liters: receiveLiters,
            unitCost: 28.5,
          ),
        ],
      );

      await repo.confirmReceipt(
        batchKey: batchKey,
        receivedByDeliveryId: const {},
        userId: fx.userId,
      );

      final tank = await TankRepository().getById(fx.tankId);
      expect(tank!.currentLiters, closeTo(4500, 0.001));

      final batch = await repo.getBatch(batchKey);
      expect(batch!.isReceived, isTrue);
      expect(batch.lines.single.receivedLiters, receiveLiters);
    });

    test('rolls back all tank updates when one line exceeds capacity', () async {
      final fx = await TestFixtures.seedPosStation(tankLiters: 4000);
      final tank2Id = await TestFixtures.seedSecondTank(
        fuelTypeId: fx.fuelTypeId,
        currentLiters: 9900,
        capacity: 10000,
      );
      final supplierId = await TestFixtures.seedSupplier();

      final repo = FuelDeliveryRepository();
      final batchKey = await repo.recordBatchImport(
        supplierId: supplierId,
        userId: fx.userId,
        lines: [
          FuelImportLine(tankId: fx.tankId, liters: 100, unitCost: 28),
          FuelImportLine(tankId: tank2Id, liters: 200, unitCost: 28),
        ],
      );

      final batch = await repo.getBatch(batchKey);
      expect(batch, isNotNull);

      expect(
        () => repo.confirmReceipt(
          batchKey: batchKey,
          receivedByDeliveryId: const {},
          userId: fx.userId,
        ),
        throwsA(isA<StateError>()),
      );

      final tank1 = await TankRepository().getById(fx.tankId);
      final tank2 = await TankRepository().getById(tank2Id);
      expect(tank1!.currentLiters, closeTo(4000, 0.001));
      expect(tank2!.currentLiters, closeTo(9900, 0.001));

      final pending = await repo.getBatch(batchKey);
      expect(pending!.isPending, isTrue);
    });
  });
}
