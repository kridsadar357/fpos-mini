import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/license_features.dart';
import '../../core/utils/money_utils.dart';
import '../../data/models/fuel_type.dart';
import '../../data/models/promotion.dart';
import '../../data/models/user.dart';
import '../../data/models/dispenser.dart';
import '../../data/models/customer.dart';
import '../../data/models/shift.dart';

/// Ephemeral state for a single POS transaction in progress.
/// Reset to null whenever the cashier logs out or completes a sale.
class AppState extends ChangeNotifier {
  AppUser? _user;
  Shift? _shift;
  Dispenser? _selectedDispenser;
  Map<String, dynamic>? _selectedNozzle;
  FuelType? _fuel;
  PaymentMethod? _paymentMethod;
  double _fuelAmount = 0;     // in currency, NOT liters — station POS convention
  double _receivedAmount = 0;
  Promotion? _promotion;
  double _promotionAmount = 0;
  int? _discountId;
  double _discountAmount = 0;
  bool _printRequested = true;
  String _licenseType = 'free';
  String? _backupWarning;
  Customer? _selectedCustomer;
  String _rawInput = '';
  bool _inputtingLiters = false; // toggle between amount mode and liters mode

  AppUser? get user => _user;
  Shift? get shift => _shift;
  Dispenser? get selectedDispenser => _selectedDispenser;
  Map<String, dynamic>? get selectedNozzle => _selectedNozzle;
  FuelType? get fuel => _fuel;
  PaymentMethod? get paymentMethod => _paymentMethod;
  double get fuelAmount => _fuelAmount;
  double get receivedAmount => _receivedAmount;
  Promotion? get promotion => _promotion;
  double get promotionAmount => _promotionAmount;
  int? get discountId => _discountId;
  double get discountAmount => _discountAmount;
  bool get printRequested => _printRequested;
  String get licenseType => _licenseType;
  String? get backupWarning => _backupWarning;
  LicenseTier get licenseTier => LicenseFeatures.tierFrom(_licenseType);
  bool canUse(AppFeature feature) =>
      LicenseFeatures.isEnabled(licenseTier, feature);
  bool get isPro => canUse(AppFeature.promotions);
  Customer? get selectedCustomer => _selectedCustomer;
  /// ทะเบียนรถจากลูกค้าที่เลือก (ถ้ามี)
  String get vehiclePlate => _selectedCustomer?.vehiclePlate ?? '';
  String get rawInput => _rawInput;
  bool get inputtingLiters => _inputtingLiters;

  double get _effectiveAmount {
    if (_inputtingLiters) return 0;
    if (_fuelAmount > 0) return _fuelAmount;
    return double.tryParse(_rawInput) ?? 0;
  }

  double get liters {
    if (_fuel == null || _fuel!.pricePerLiter <= 0) return 0;
    if (_inputtingLiters) {
      return double.tryParse(_rawInput) ?? 0;
    }
    return _effectiveAmount / _fuel!.pricePerLiter;
  }

  double get subtotal {
    if (_fuel == null) return 0;
    if (_inputtingLiters) {
      return MoneyUtils.fuelSubtotalFromLiters(
        liters: liters,
        pricePerLiter: _fuel!.pricePerLiter,
      );
    }
    return MoneyUtils.ceilBaht(_effectiveAmount);
  }

  double get total => MoneyUtils.payableTotal(
        subtotal: subtotal,
        promotionAmount: _promotionAmount,
        discountAmount: _discountAmount,
      );
  double get change =>
      (_receivedAmount - total).clamp(0, double.infinity);

  void setUser(AppUser? u) {
    _user = u;
    notifyListeners();
  }

  void setShift(Shift? s) {
    _shift = s;
    notifyListeners();
  }

  void setLicenseType(String type) {
    _licenseType = type;
    notifyListeners();
  }

  void setBackupWarning(String? message) {
    if (_backupWarning == message) return;
    _backupWarning = message;
    notifyListeners();
  }

  void clearBackupWarning() {
    setBackupWarning(null);
  }

  void selectDispenser(Dispenser? d) {
    _selectedDispenser = d;
    _selectedNozzle = null;
    _fuel = null;
    notifyListeners();
  }

  void selectNozzle(Map<String, dynamic> nozzleData) {
    _selectedNozzle = nozzleData;
    // Map to FuelType model for compatibility with existing components
    _fuel = FuelType(
      id: nozzleData['fuel_type_id'],
      code: nozzleData['fuel_code'],
      name: nozzleData['fuel_name'],
      pricePerLiter: (nozzleData['price_per_liter'] as num).toDouble(),
      colorHex: nozzleData['color_hex'],
    );
    _receivedAmount = 0;
    _clearPromo();
    _syncAmountFromRaw();
    notifyListeners();
  }

  void selectFuel(FuelType f) {
    _fuel = f;
    _receivedAmount = 0;
    _clearPromo();
    _syncAmountFromRaw();
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod m) {
    _paymentMethod = m;
    // non-cash payments don't need a "received" input
    if (!m.requiresChange) _receivedAmount = 0;
    notifyListeners();
  }

  void setFuelAmount(double amount) {
    _fuelAmount = amount;
    notifyListeners();
  }

  void setReceivedAmount(double amount) {
    _receivedAmount = amount;
    notifyListeners();
  }

  void applyPromotion(Promotion? p, double amount) {
    _promotion = p;
    _promotionAmount = amount;
    notifyListeners();
  }

  void applyDiscount({int? id, double amount = 0}) {
    _discountId = id;
    _discountAmount = amount;
    notifyListeners();
  }

  void setPrintRequested(bool v) {
    _printRequested = v;
    notifyListeners();
  }

  void _clearPromo() {
    _promotion = null;
    _promotionAmount = 0;
    _discountId = null;
    _discountAmount = 0;
  }

  void resetTransaction() {
    _selectedDispenser = null;
    _selectedNozzle = null;
    _fuel = null;
    _paymentMethod = null;
    _fuelAmount = 0;
    _receivedAmount = 0;
    _selectedCustomer = null;
    _rawInput = '';
    _inputtingLiters = false;
    _clearPromo();
    _printRequested = true;
    notifyListeners();
  }
  
  void setCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// ตั้งทะเบียนรถสำหรับรายการขายปัจจุบัน (ไม่มีลูกค้า → สร้าง legacy plate)
  void setVehiclePlate(String plate) {
    final trimmed = plate.trim().toUpperCase();
    if (trimmed.isEmpty) {
      final c = _selectedCustomer;
      if (c != null &&
          c.id == null &&
          !c.hasTaxInvoiceData &&
          (c.fleetCardNo == null || c.fleetCardNo!.trim().isEmpty)) {
        _selectedCustomer = null;
      } else if (c != null) {
        _selectedCustomer = c.copyWith(clearVehiclePlate: true);
      }
      notifyListeners();
      return;
    }

    final c = _selectedCustomer;
    _selectedCustomer =
        c == null ? Customer.legacyPlate(trimmed) : c.copyWith(vehiclePlate: trimmed);
    notifyListeners();
  }

  void toggleInputMode(bool isLiters) {
    if (_inputtingLiters == isLiters) return;

    if (isLiters) {
      final l = liters;
      _rawInput = l > 0 ? _trimTrailingZeros(l) : '';
    } else {
      final baht = subtotal;
      _fuelAmount = baht;
      _rawInput = baht > 0 ? _trimTrailingZeros(baht) : '';
    }
    _inputtingLiters = isLiters;
    notifyListeners();
  }

  /// ตั้งยอดด่วน (บาท) จากปุ่มลัด
  void setQuickBaht(double baht) {
    _inputtingLiters = false;
    _fuelAmount = baht;
    _rawInput = _trimTrailingZeros(baht);
    notifyListeners();
  }

  void appendInput(String char) {
    if (char == 'CLEAR') {
      _rawInput = '';
    } else if (char == 'BACK') {
      if (_rawInput.isNotEmpty) {
        _rawInput = _rawInput.substring(0, _rawInput.length - 1);
      }
    } else if (char == '.') {
      if (!_rawInput.contains('.')) {
        _rawInput = _rawInput.isEmpty ? '0.' : '$_rawInput.';
      }
    } else {
      if (_rawInput == '0') {
        _rawInput = char;
      } else {
        _rawInput += char;
      }
    }

    _syncAmountFromRaw();
    notifyListeners();
  }

  void _syncAmountFromRaw() {
    final val = double.tryParse(_rawInput) ?? 0;
    if (!_inputtingLiters) {
      _fuelAmount = val;
    }
  }

  static String _trimTrailingZeros(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  void logout() {
    _user = null;
    _shift = null;
    resetTransaction();
  }

  Map<String, dynamic> toSuspendPayload() => {
        'dispenser_id': _selectedDispenser?.id,
        'dispenser_name': _selectedDispenser?.name,
        'nozzle': _selectedNozzle,
        'fuel_amount': _fuelAmount,
        'raw_input': _rawInput,
        'inputting_liters': _inputtingLiters,
        if (_selectedCustomer != null)
          'customer': _selectedCustomer!.toJsonMap(),
        'payment_method': _paymentMethod?.name,
      };

  void restoreFromPayload(Map<String, dynamic> p) {
    _selectedNozzle = p['nozzle'] as Map<String, dynamic>?;
    if (_selectedNozzle != null) {
      _fuel = FuelType(
        id: _selectedNozzle!['fuel_type_id'] as int,
        code: _selectedNozzle!['fuel_code'] as String,
        name: _selectedNozzle!['fuel_name'] as String,
        pricePerLiter: (_selectedNozzle!['price_per_liter'] as num).toDouble(),
        colorHex: _selectedNozzle!['color_hex'] as String?,
      );
    }
    _fuelAmount = (p['fuel_amount'] as num?)?.toDouble() ?? 0;
    _rawInput = p['raw_input'] as String? ?? '';
    _inputtingLiters = p['inputting_liters'] as bool? ?? false;
    final cust = p['customer'];
    if (cust is Map<String, dynamic>) {
      _selectedCustomer = Customer.fromJsonMap(cust);
    } else {
      final plate = p['vehicle_plate'] as String? ?? '';
      _selectedCustomer =
          plate.isNotEmpty ? Customer.legacyPlate(plate) : null;
    }
    final pm = p['payment_method'] as String?;
    if (pm != null) {
      _paymentMethod = PaymentMethod.values.firstWhere(
        (e) => e.name == pm,
        orElse: () => PaymentMethod.cash,
      );
    }
    _clearPromo();
    notifyListeners();
  }
}
