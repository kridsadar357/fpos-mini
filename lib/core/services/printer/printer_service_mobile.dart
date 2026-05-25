import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../data/models/customer.dart';
import '../../../data/models/promotion.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../constants/app_constants.dart';
import '../database_service.dart';
import '../receipt_renderer.dart';
import '../receipt_template_service.dart';
import 'bluetooth_device_model.dart';

export 'bluetooth_device_model.dart';

/// Bluetooth ESC/POS printer service using print_bluetooth_thermal.
/// Supports both Android (SPP) and iOS (BLE).
class BluetoothPrinterService {
  BluetoothPrinterService._();
  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  static const int maxPrintAttempts = 3;
  static const Duration retryDelay = Duration(milliseconds: 800);
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration writeTimeout = Duration(seconds: 12);

  BluetoothDevice? _device;
  PaperSize _paperSize = PaperSize.mm80;

  Future<bool> get isConnected async {
    if (!await hasBluetoothPermission()) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  BluetoothDevice? get device => _device;
  PaperSize get paperSize => _paperSize;
  String get paperSizeLabel => _paperSize == PaperSize.mm58 ? '58 mm' : '80 mm';

  /// Load saved paper width only — do not touch Bluetooth until permission granted.
  Future<void> init() async {
    await loadPaperSize();
    await ReceiptTemplateService.instance.load();
    if (await hasBluetoothPermission()) {
      await connectLastUsed();
    }
  }

  Future<void> loadPaperSize() async {
    final repo = SettingsRepository();
    final saved = await repo.get('printer_paper_size', defaultValue: '80');
    _paperSize = saved == '58' ? PaperSize.mm58 : PaperSize.mm80;
  }

  Future<void> savePaperSize(PaperSize size) async {
    _paperSize = size;
    final repo = SettingsRepository();
    await repo.set('printer_paper_size', size == PaperSize.mm58 ? '58' : '80');
  }

  /// Android 12+ requires Nearby devices (BLUETOOTH_CONNECT / BLUETOOTH_SCAN).
  Future<bool> hasBluetoothPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensurePermissions({bool request = true}) async {
    if (!Platform.isAndroid) return true;

    if (await hasBluetoothPermission()) return true;
    if (!request) return false;

    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final handlerOk = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    return handlerOk && await hasBluetoothPermission();
  }

  Future<bool> openPermissionSettings() => openAppSettings();

  Future<List<BluetoothDevice>> listBondedDevices() async {
    if (!await ensurePermissions()) return [];
    try {
      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;
      return devices
          .map((d) => BluetoothDevice(address: d.macAdress, name: d.name))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> connectTo(BluetoothDevice device) async {
    if (!await ensurePermissions()) return false;
    await disconnect();
    try {
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.address,
      ).timeout(connectTimeout, onTimeout: () => false);
      if (result) {
        _device = device;
        final repo = SettingsRepository();
        await repo.set('printer_mac', device.address);
        await repo.set('printer_name', device.name ?? 'Printer');
      }
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureConnected({bool reconnect = false}) async {
    if (!await ensurePermissions()) return false;
    if (!reconnect && await isConnected) return true;
    if (reconnect) await disconnect();
    return connectLastUsed();
  }

  Future<bool> _writeBytesWithRetry(List<int> bytes) async {
    for (var attempt = 1; attempt <= maxPrintAttempts; attempt++) {
      final reconnect = attempt > 1;
      if (!await _ensureConnected(reconnect: reconnect)) {
        if (attempt < maxPrintAttempts) {
          await Future.delayed(retryDelay);
        }
        continue;
      }

      try {
        final ok = await PrintBluetoothThermal.writeBytes(bytes)
            .timeout(writeTimeout, onTimeout: () => false);
        if (ok) return true;
      } catch (_) {}

      if (attempt < maxPrintAttempts) {
        await disconnect();
        await Future.delayed(retryDelay);
      }
    }
    return false;
  }

  Future<bool> connectLastUsed() async {
    if (!await ensurePermissions()) return false;
    final repo = SettingsRepository();
    final mac = await repo.get('printer_mac', defaultValue: '');
    if (mac.isEmpty) return false;
    final devices = await listBondedDevices();
    final match = devices.where((d) => d.address == mac).toList();
    if (match.isEmpty) return false;
    return connectTo(match.first);
  }

  Future<void> disconnect() async {
    if (!await hasBluetoothPermission()) {
      _device = null;
      return;
    }
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    _device = null;
  }

  /// Render receipt bytes for the given transaction.
  Future<Uint8List> renderReceipt({
    required Transaction tx,
    required String fuelName,
    required String cashierName,
    Customer? customer,
    Promotion? promotion,
    bool isDraft = false,
  }) async {
    await ReceiptTemplateService.instance.load();
    return ReceiptRenderer.build(
      paperSize: _paperSize,
      tx: tx,
      fuelName: fuelName,
      cashierName: cashierName,
      customer: customer,
      promotion: promotion,
      isDraft: isDraft,
    );
  }

  /// Send rendered bytes to the printer
  Future<bool> printReceipt({
    required Transaction tx,
    required String fuelName,
    required String cashierName,
    Customer? customer,
    Promotion? promotion,
    bool isDraft = false,
  }) async {
    if (!await ensurePermissions()) return false;
    try {
      final bytes = await renderReceipt(
        tx: tx,
        fuelName: fuelName,
        cashierName: cashierName,
        customer: customer,
        promotion: promotion,
        isDraft: isDraft,
      );
      final result = await _writeBytesWithRetry(bytes);
      if (result) {
        DatabaseService.instance
            .audit(tx.cashierId, 'print', details: 'receipt=${tx.receiptNo}');
      }
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> printTestPage() async {
    if (!await ensurePermissions()) return false;
    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(_paperSize, profile);
      List<int> bytes = [];
      bytes += gen.reset();
      bytes += gen.text('--- TEST PAGE ---',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += gen.text(DateTime.now().toIso8601String(),
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(2);
      bytes += gen.cut();
      return _writeBytesWithRetry(bytes);
    } catch (_) {
      return false;
    }
  }

  void setPaperSize(PaperSize size) => _paperSize = size;

  Future<bool> printTestPageWithInfo() async {
    if (!await ensurePermissions()) return false;
    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(_paperSize, profile);
      final repo = SettingsRepository();
      final station = await repo.get('station_name',
          defaultValue: AppConstants.appName);
      List<int> bytes = [];
      bytes += gen.reset();
      bytes += gen.text(station,
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += gen.text('FUEL POS — TEST',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += gen.text('Paper: $paperSizeLabel',
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.text(DateTime.now().toIso8601String(),
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.hr();
      bytes += gen.text('12345678901234567890',
          styles: const PosStyles(align: PosAlign.center));
      bytes += gen.feed(2);
      bytes += gen.cut();
      return _writeBytesWithRetry(bytes);
    } catch (_) {
      return false;
    }
  }
}
