import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory? _tempDir;
bool _ffiReady = false;

Future<void> setUpTestDatabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!_ffiReady) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }

  _tempDir ??= await Directory.systemTemp.createTemp('fuel_pos_test_');
  final path = '${_tempDir!.path}/test_${DateTime.now().microsecondsSinceEpoch}.db';
  DatabaseService.instance.configureForTesting(dbPath: path);
  await DatabaseService.instance.database;
}

Future<void> tearDownTestDatabase() async {
  await DatabaseService.instance.resetForTesting();
}

Future<void> tearDownAllTestDatabase() async {
  await DatabaseService.instance.resetForTesting();
  if (_tempDir != null && await _tempDir!.exists()) {
    await _tempDir!.delete(recursive: true);
    _tempDir = null;
  }
}
