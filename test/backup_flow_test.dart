import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/constants/app_constants.dart';
import 'package:fuel_pos/core/services/backup_service.dart';
import 'package:fuel_pos/core/services/database_service.dart';
import 'package:fuel_pos/core/utils/money_utils.dart';
import 'package:fuel_pos/data/repositories/settings_repository.dart';
import 'package:fuel_pos/data/repositories/transaction_repository.dart';
import 'package:sqflite/sqflite.dart';

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

  test('copyDatabaseFile produces valid backup with sale data', () async {
    final fx = await TestFixtures.seedPosStation();
    const liters = 8.0;
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

    final srcPath = await DatabaseService.instance.databasePath;
    final backupPath = '$srcPath.backup_copy.db';
    await DatabaseService.instance.copyDatabaseFile(backupPath);

    final verify = await DatabaseService.instance.verifyBackupFile(backupPath);
    expect(verify.ok, isTrue, reason: verify.message);

    final probe = await openDatabase(backupPath, readOnly: true);
    final txCount = Sqflite.firstIntValue(
          await probe.rawQuery('SELECT COUNT(*) FROM transactions'),
        ) ??
        0;
    final shiftCount = Sqflite.firstIntValue(
          await probe.rawQuery(
            "SELECT COUNT(*) FROM shifts WHERE status = 'open'",
          ),
        ) ??
        0;
    await probe.close();

    expect(txCount, 1);
    expect(shiftCount, 1);

    await File(backupPath).delete();
  });

  test('verifyBackupFile rejects corrupt file', () async {
    final srcPath = await DatabaseService.instance.databasePath;
    final badPath = '$srcPath.bad.db';
    await File(badPath).writeAsString('not a sqlite database');

    final verify = await DatabaseService.instance.verifyBackupFile(badPath);
    expect(verify.ok, isFalse);

    await File(badPath).delete();
  });

  test('evaluateBackupHealth marks stale when last backup is old', () async {
    final repo = SettingsRepository();
    final old = DateTime.now().subtract(
      const Duration(days: AppConstants.backupWarnDays + 2),
    );
    await repo.set('last_local_backup_at', old.toIso8601String());

    final health = await BackupService.instance.evaluateBackupHealth();
    expect(health.isStale, isTrue);
    expect(health.daysSinceLastBackup, greaterThan(AppConstants.backupWarnDays));
    expect(health.message, isNotNull);
  });

  test('evaluateBackupHealth ok when backup timestamp is recent', () async {
    final repo = SettingsRepository();
    await repo.set(
      'last_local_backup_at',
      DateTime.now().toIso8601String(),
    );

    final health = await BackupService.instance.evaluateBackupHealth();
    expect(health.isStale, isFalse);
    expect(
      health.daysSinceLastBackup,
      lessThanOrEqualTo(AppConstants.backupWarnDays),
    );
  });

  test('ensureCloudToken reports missing token without refresh', () async {
    final result = await BackupService.instance.ensureCloudToken(
      refreshFromServer: false,
    );
    expect(result.ok, isFalse);
    expect(result.tokenHint, isEmpty);
  });
}
