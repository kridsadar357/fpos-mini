import 'dart:typed_data';
import 'package:esc_pos_utils/esc_pos_utils.dart';

import '../../../data/models/customer.dart';
import '../../../data/models/promotion.dart';
import '../../../data/models/transaction.dart';
import 'bluetooth_device_model.dart';

export 'bluetooth_device_model.dart';

class BluetoothPrinterService {
  BluetoothPrinterService._();
  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  static const int maxPrintAttempts = 3;

  Future<bool> get isConnected async => false;
  BluetoothDevice? get device => null;

  Future<bool> hasBluetoothPermission() async => true;

  Future<bool> ensurePermissions({bool request = true}) async => true;

  Future<bool> openPermissionSettings() async => false;
  Future<List<BluetoothDevice>> listBondedDevices() async => [];
  Future<bool> connectTo(BluetoothDevice device) async => false;
  Future<bool> connectLastUsed() async => false;
  Future<void> disconnect() async {}
  
  Future<Uint8List> renderReceipt({
    required Transaction tx,
    required String fuelName,
    required String cashierName,
    Customer? customer,
    Promotion? promotion,
    bool isDraft = false,
  }) async =>
      Uint8List(0);

  Future<bool> printReceipt({
    required Transaction tx,
    required String fuelName,
    required String cashierName,
    Customer? customer,
    Promotion? promotion,
    bool isDraft = false,
  }) async =>
      false;

  Future<bool> printTestPage() async => false;

  Future<bool> printTestPageWithInfo() async => false;

  PaperSize get paperSize => PaperSize.mm80;

  String get paperSizeLabel => '80 mm';

  Future<void> init() async {}

  Future<void> loadPaperSize() async {}

  Future<void> savePaperSize(PaperSize size) async {}

  void setPaperSize(PaperSize size) {}
}
