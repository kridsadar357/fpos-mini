import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/database_import_report.dart';
import '../../core/services/database_service.dart';
import '../../core/services/license_service.dart';
import '../../core/services/setup_draft_service.dart';
import '../../core/services/splash_init_cache.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/text_match_util.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/repositories/settings_repository.dart';
import '../widgets/app_logo.dart';
import '../widgets/high_end_dialog.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

enum _SetupEntry { landing, wizard, importReview }

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  static const _totalSteps = 7;
  static const _licenseStepIndex = 5;

  int _currentStep = 0;
  int _step2Tab = 0;
  int _dispenserIdx = 0;
  int _dispenserSubStep = 0;
  int _printerPage = 0;
  static const _listPageSize = 2;

  // Step 1 — บริษัท
  final _companyCtrl = TextEditingController(text: 'FUEL POS STATION');
  final _taxIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _footerCtrl =
      TextEditingController(text: 'ขอบคุณที่ใช้บริการ — เดินทางปลอดภัย');
  bool _vatInclusive = true;
  String? _logoPath;

  // Step 2 — ถัง / น้ำมัน
  List<Map<String, dynamic>> _fuelTypes = [];
  final List<Map<String, dynamic>> _tanks = [];

  // Step 3 — ตู้จ่าย
  final List<Map<String, dynamic>> _dispensers = [];

  // Step 4 — สินค้าทั่วไป
  bool _sellProducts = false;

  // Step 5 — เครื่องพิมพ์
  bool _printerSkipped = false;
  List<BluetoothDevice> _printerDevices = [];
  bool _printerScanning = false;
  bool _printerConnected = false;

  // Step 6 — License (บังคับ)
  final _licenseCtrl = TextEditingController();
  bool _licenseVerified = false;
  String? _licenseCustomerName;
  bool _verifyingLicense = false;

  // Step 7 — Admin
  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _adminPassConfirmCtrl = TextEditingController();

  final _settings = SettingsRepository();
  final _db = DatabaseService.instance;

  _SetupEntry _entry = _SetupEntry.landing;
  String? _importFilePath;
  String? _importFileName;
  DatabaseImportReport? _importReport;
  bool _importBusy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _taxIdCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _footerCtrl.dispose();
    _licenseCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminPassConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final types = await _db.query('fuel_types', orderBy: 'id ASC');
    _licenseVerified = await LicenseService.instance.isLicenseVerified();
    final draft = await SetupDraftService.instance.load();

    if (!mounted) return;
    setState(() {
      _fuelTypes = types
          .map(
            (t) => {
              'id': t['id'],
              'code': t['code'],
              'name': t['name'],
              'price': (t['price_per_liter'] as num).toDouble(),
              'color_hex': t['color_hex'],
            },
          )
          .toList();
      if (_fuelTypes.isEmpty) {
        _fuelTypes.add({
          'code': 'DSL',
          'name': 'ดีเซล B7',
          'price': 32.0,
          'color_hex': '#2B7A3E',
        });
      }
    });

    if (draft != null) {
      _applyDraft(draft);
      _entry = _SetupEntry.wizard;
    }

    if (_licenseVerified && _currentStep < _licenseStepIndex) {
      _currentStep = _licenseStepIndex;
    }

    if (mounted) setState(() {});
  }

  void _applyDraft(Map<String, dynamic> draft) {
    _companyCtrl.text = draft['company_name'] as String? ?? _companyCtrl.text;
    _taxIdCtrl.text = draft['tax_id'] as String? ?? '';
    _addressCtrl.text = draft['address'] as String? ?? '';
    _phoneCtrl.text = draft['phone'] as String? ?? '';
    _footerCtrl.text = draft['receipt_footer'] as String? ?? _footerCtrl.text;
    _vatInclusive = draft['vat_inclusive'] as bool? ?? _vatInclusive;
    _logoPath = draft['logo_path'] as String?;

    final fuels = draft['fuel_types'];
    if (fuels is List && fuels.isNotEmpty) {
      _fuelTypes = fuels.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    _tanks.clear();
    final tanks = draft['tanks'];
    if (tanks is List) {
      for (final t in tanks) {
        _tanks.add(Map<String, dynamic>.from(t as Map));
      }
    }

    _dispensers.clear();
    final dispensers = draft['dispensers'];
    if (dispensers is List) {
      for (final d in dispensers) {
        _dispensers.add(Map<String, dynamic>.from(d as Map));
      }
    }

    _sellProducts = draft['sell_products'] as bool? ?? false;
    _printerSkipped = draft['printer_skipped'] as bool? ?? false;
    _licenseCtrl.text = draft['license_key'] as String? ?? '';

    final step = draft['step'] as int? ?? 0;
    _currentStep = step.clamp(0, _totalSteps - 1);
    if (_licenseVerified && _currentStep < _licenseStepIndex) {
      _currentStep = _licenseStepIndex;
    }
  }

  Map<String, dynamic> _buildDraft({int? step}) {
    return {
      'step': step ?? _currentStep,
      'company_name': _companyCtrl.text,
      'tax_id': _taxIdCtrl.text,
      'address': _addressCtrl.text,
      'phone': _phoneCtrl.text,
      'receipt_footer': _footerCtrl.text,
      'vat_inclusive': _vatInclusive,
      'logo_path': _logoPath,
      'fuel_types': _fuelTypes,
      'tanks': _tanks,
      'dispensers': _dispensers,
      'sell_products': _sellProducts,
      'printer_skipped': _printerSkipped,
      'license_key': _licenseCtrl.text,
    };
  }

  Future<void> _persistDraft({int? step}) async {
    await SetupDraftService.instance.save(_buildDraft(step: step));
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/station_logo.png');
    await File(picked.path).copy(dest.path);
    setState(() => _logoPath = dest.path);
  }

  Future<void> _scanPrinters() async {
    setState(() => _printerScanning = true);
    final devices = await BluetoothPrinterService.instance.listBondedDevices();
    final connected = await BluetoothPrinterService.instance.isConnected;
    if (!mounted) return;
    setState(() {
      _printerDevices = devices;
      _printerConnected = connected;
      _printerScanning = false;
      _printerPage = 0;
    });
  }

  Future<void> _connectPrinter(BluetoothDevice d) async {
    final ok = await BluetoothPrinterService.instance.connectTo(d);
    if (!mounted) return;
    setState(() {
      _printerConnected = ok;
      if (ok) _printerSkipped = false;
    });
    ToastUtils.show(context, ok ? 'เชื่อมต่อเครื่องพิมพ์แล้ว' : 'เชื่อมต่อไม่สำเร็จ');
  }

  Future<void> _verifyLicense() async {
    if (_licenseCtrl.text.trim().isEmpty) {
      ToastUtils.show(context, 'กรุณากรอก Product Key');
      return;
    }
    setState(() => _verifyingLicense = true);
    final res =
        await LicenseService.instance.verifyProductKey(_licenseCtrl.text);
    if (!mounted) return;
    setState(() => _verifyingLicense = false);

    if (res['success'] == true) {
      setState(() {
        _licenseVerified = true;
        _licenseCustomerName = res['customer_name']?.toString();
      });
      await _persistDraft(step: _licenseStepIndex);
      if (!mounted) return;
      ToastUtils.show(
        context,
        'ยืนยัน License สำเร็จ${_licenseCustomerName != null ? ' — $_licenseCustomerName' : ''}',
      );
    } else {
      ToastUtils.show(context, res['message']?.toString() ?? 'ยืนยันไม่สำเร็จ');
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_companyCtrl.text.trim().isEmpty) {
          ToastUtils.show(context, 'กรุณาระบุชื่อบริษัท/สถานี');
          return false;
        }
        return true;
      case 1:
        if (_tanks.isEmpty) {
          ToastUtils.show(context, 'กรุณาเพิ่มถังน้ำมันอย่างน้อย 1 ถัง');
          return false;
        }
        return true;
      case 2:
        if (_dispensers.isEmpty) {
          ToastUtils.show(context, 'กรุณาเพิ่มตู้จ่ายอย่างน้อย 1 ตู้');
          return false;
        }
        for (final d in _dispensers) {
          final nozzles = d['nozzles'] as List? ?? [];
          if (nozzles.isEmpty) {
            ToastUtils.show(context, 'ตู้ ${d['name']} ต้องมีมือจ่ายอย่างน้อย 1 หัว');
            return false;
          }
        }
        return true;
      case _licenseStepIndex:
        if (!_licenseVerified) {
          ToastUtils.show(context, 'กรุณายืนยัน Product Key ก่อนดำเนินการต่อ');
          return false;
        }
        return true;
      case 6:
        if (_adminUserCtrl.text.trim().isEmpty) {
          ToastUtils.show(context, 'กรุณาระบุชื่อผู้ใช้');
          return false;
        }
        if (_adminPassCtrl.text.length < 4) {
          ToastUtils.show(context, 'รหัสผ่านต้องมีอย่างน้อย 4 ตัวอักษร');
          return false;
        }
        if (_adminPassCtrl.text != _adminPassConfirmCtrl.text) {
          ToastUtils.show(context, 'รหัสผ่านไม่ตรงกัน');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _next() async {
    if (!_validateStep(_currentStep)) return;

    if (_currentStep < _totalSteps - 1) {
      final nextStep = _currentStep + 1;
      if (nextStep <= 4) {
        await _persistDraft(step: nextStep);
      } else if (nextStep == _licenseStepIndex) {
        await _persistDraft(step: _licenseStepIndex);
      }
      setState(() {
        if (nextStep == 2) _dispenserSubStep = 0;
        _currentStep = nextStep;
      });
    } else {
      await _finish();
    }
  }

  void _prev() {
    if (_currentStep == 2 && _dispenserSubStep == 1) {
      setState(() => _dispenserSubStep = 0);
      return;
    }
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
        if (_currentStep == 2) _dispenserSubStep = 0;
      });
    }
  }

  Future<void> _handleBack() async {
    if (_entry == _SetupEntry.importReview) {
      setState(() {
        _entry = _SetupEntry.landing;
        _importFilePath = null;
        _importFileName = null;
        _importReport = null;
      });
      return;
    }
    if (_entry == _SetupEntry.landing) {
      SystemNavigator.pop();
      return;
    }
    if (_currentStep == _licenseStepIndex && !_licenseVerified) {
      await _persistDraft(step: _licenseStepIndex);
      if (!mounted) return;
      ToastUtils.show(context, 'ต้องยืนยัน License ก่อนใช้งาน — บันทึกความคืบหน้าแล้ว');
      SystemNavigator.pop();
      return;
    }
    if (_currentStep > 0) {
      _prev();
    } else {
      setState(() => _entry = _SetupEntry.landing);
    }
  }

  void _startNewSetup() {
    setState(() => _entry = _SetupEntry.wizard);
  }

  Future<void> _pickImportDatabase() async {
    if (kIsWeb) {
      ToastUtils.show(context, 'การนำเข้าไฟล์ .db ไม่รองรับบน Web');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final report = await DatabaseService.instance.validateImportFile(path);
    if (!mounted) return;

    setState(() {
      _importFilePath = path;
      _importFileName = result.files.single.name;
      _importReport = report;
      _entry = _SetupEntry.importReview;
    });
  }

  Future<void> _confirmImportDatabase() async {
    if (_importFilePath == null || _importReport == null || !_importReport!.ok) {
      ToastUtils.show(context, 'ไฟล์ไม่ผ่านการตรวจสอบ schema');
      return;
    }

    final confirmed = await HighEndDialog.show<bool>(
      context: context,
      title: 'นำเข้าฐานข้อมูล',
      message:
          'ไฟล์ "${_importFileName ?? ''}" จะแทนที่ข้อมูลชั่วคราวในเครื่อง\n'
          'Schema: ${_importReport!.versionLabel}\n\n'
          'ดำเนินการต่อหรือไม่?',
      icon: Icons.upload_file_rounded,
      iconColor: AppColors.corporateBlue,
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          expand: false,
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'นำเข้า',
          expand: false,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importBusy = true);
    try {
      final result =
          await DatabaseService.instance.importDatabaseFile(_importFilePath!);
      if (!mounted) return;
      if (!result.ok) {
        ToastUtils.show(context, result.message);
        return;
      }

      await SetupDraftService.instance.clear();
      await _db.audit(null, 'setup_import',
          details: _importFileName ?? _importFilePath);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) ToastUtils.show(context, 'นำเข้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _importBusy = false);
    }
  }

  Future<void> _finish() async {
    if (!_licenseVerified) {
      ToastUtils.show(context, 'กรุณายืนยัน License ก่อน');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    try {
      await _settings.set('station_name', _companyCtrl.text.trim());
      await _settings.set('station_tax_id', _taxIdCtrl.text.trim());
      await _settings.set('station_address', _addressCtrl.text.trim());
      await _settings.set('station_phone', _phoneCtrl.text.trim());
      await _settings.set('receipt_footer', _footerCtrl.text.trim());
      await _settings.set('vat_inclusive', _vatInclusive.toString());
      await _settings.set('vat_enabled', _vatInclusive.toString());
      await _settings.set('products_enabled', _sellProducts.toString());
      if (_logoPath != null) {
        await _settings.set('station_logo_path', _logoPath!);
      }

      final dbConn = await _db.database;
      await dbConn.execute('DELETE FROM nozzles');
      await dbConn.execute('DELETE FROM dispensers');
      await dbConn.execute('DELETE FROM tanks');

      final Map<String, int> fuelIdByKey = {};
      for (final ft in _fuelTypes) {
        final id = ft['id'] as int?;
        final payload = {
          'code': ft['code'] ?? 'FUEL',
          'name': ft['name'] ?? 'น้ำมัน',
          'price_per_liter': (ft['price'] as num?)?.toDouble() ?? 0,
          'color_hex': ft['color_hex'] ?? '#163172',
          'is_active': 1,
        };
        if (id != null) {
          await _db.update('fuel_types', payload, where: 'id = ?', whereArgs: [id]);
          fuelIdByKey['id:$id'] = id;
        } else {
          final newId = await _db.insert('fuel_types', payload);
          fuelIdByKey['id:$newId'] = newId;
          ft['id'] = newId;
        }
      }

      final Map<String, int> tankMap = {};
      for (final t in _tanks) {
        var fuelTypeId = t['fuel_type_id'] as int?;
        if (fuelTypeId == null && t['fuel_key'] != null) {
          fuelTypeId = fuelIdByKey[t['fuel_key'] as String];
        }
        fuelTypeId ??= _fuelTypes.isNotEmpty ? _fuelTypes.first['id'] as int? : 1;

        final id = await _db.insert('tanks', {
          'name': t['name'],
          'fuel_type_id': fuelTypeId,
          'capacity': (t['capacity'] as num).toDouble(),
          'current_liters': (t['current_liters'] as num).toDouble(),
        });
        tankMap[t['name'] as String] = id;
      }

      for (final d in _dispensers) {
        final dispenserId = await _db.insert('dispensers', {
          'name': d['name'],
          'is_active': 1,
        });
        final nozzles = d['nozzles'] as List? ?? [];
        for (final n in nozzles) {
          final tankName = n['tank_name'] as String? ?? '';
          await _db.insert('nozzles', {
            'dispenser_id': dispenserId,
            'tank_id': tankMap[tankName] ?? tankMap.values.first,
            'nozzle_number': n['number'],
          });
        }
      }

      await _db.insert('users', {
        'username': _adminUserCtrl.text.trim(),
        'password_hash': DatabaseService.hash(_adminPassCtrl.text),
        'role': 'admin',
        'display_name': 'ผู้ดูแลระบบ',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _settings.set('is_initialized', 'true');
      await SplashInitCache.write(true);
      await SetupDraftService.instance.clear();

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) ToastUtils.show(context, 'ตั้งค่าไม่สำเร็จ: $e');
    }
  }

  List<T> _pageSlice<T>(List<T> list, int page) {
    final start = page * _listPageSize;
    if (start >= list.length) return [];
    final end = (start + _listPageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  int _pageCount(int length) =>
      length == 0 ? 1 : ((length - 1) ~/ _listPageSize) + 1;

  int _fuelIndexFor(Map<String, dynamic> tank) {
    final id = tank['fuel_type_id'];
    for (var i = 0; i < _fuelTypes.length; i++) {
      if (_fuelTypes[i]['id'] == id) return i;
    }
    return 0;
  }

  String _fuelNameFor(Map<String, dynamic> tank) {
    final i = _fuelIndexFor(tank);
    if (_fuelTypes.isEmpty) return '';
    return _fuelTypes[i.clamp(0, _fuelTypes.length - 1)]['name']
            ?.toString() ??
        '';
  }

  Color _fuelColorFromHex(String? hex) {
    try {
      final h = (hex ?? '163172').replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppColors.corporateBlue;
    }
  }

  String _tankFuelShortName(String tankName) {
    for (final t in _tanks) {
      if (t['name']?.toString() == tankName) {
        final name = _fuelNameFor(t);
        final digits = firstDigitSequence(name);
        if (digits != null) return digits;
        if (name.length <= 12) return name;
        return name.substring(0, 12);
      }
    }
    return '—';
  }

  Color _tankFuelColor(String tankName) {
    for (final t in _tanks) {
      if (t['name']?.toString() == tankName) {
        if (_fuelTypes.isEmpty) return AppColors.corporateBlue;
        final idx = _fuelIndexFor(t);
        return _fuelColorFromHex(
          _fuelTypes[idx.clamp(0, _fuelTypes.length - 1)]['color_hex']
              as String?,
        );
      }
    }
    return AppColors.corporateBlue;
  }

  List<Map<String, String>> _tankSelectOptions() {
    return _tanks.map((t) {
      final name = t['name']?.toString() ?? '';
      final fuel = _fuelNameFor(t);
      return {'name': name, 'label': '$name · $fuel', 'fuel': fuel};
    }).toList();
  }

  void _addFuelType() {
    setState(() {
      _fuelTypes.add({
        'code': 'F${_fuelTypes.length + 1}',
        'name': 'น้ำมัน ${_fuelTypes.length + 1}',
        'price': 30.0,
        'color_hex': '#163172',
      });
    });
  }

  void _addTank() {
    if (_fuelTypes.isEmpty) return;
    final ft = _fuelTypes.first;
    final key = ft['id'] != null ? 'id:${ft['id']}' : 'idx:0';
    setState(() {
      _tanks.add({
        'name': 'ถัง ${_tanks.length + 1}',
        'fuel_type_id': ft['id'],
        'fuel_key': key,
        'capacity': 10000.0,
        'current_liters': 10000.0,
      });
    });
  }

  void _addDispenser() {
    if (_dispensers.length >= 8) return;
    setState(() {
      _dispensers.add({
        'name': 'ตู้จ่าย ${_dispensers.length + 1}',
        'nozzles': <Map<String, dynamic>>[],
      });
      _dispenserIdx = _dispensers.length - 1;
    });
  }

  _WizardStepInfo _meta(int step) => _WizardStepInfo.all[step];

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panel = DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(r.r(14)),
                  border: Border.all(color: AppColors.greyLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.corporateBlue.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r.r(14)),
                  child: Column(
                    children: [
                      _buildHeader(r),
                      const Divider(height: 1, color: AppColors.greyLight),
                      Expanded(
                        child: switch (_entry) {
                          _SetupEntry.landing => _buildLandingStep(r),
                          _SetupEntry.importReview => _buildImportReviewStep(r),
                          _SetupEntry.wizard => IndexedStack(
                              index: _currentStep,
                              sizing: StackFit.expand,
                              children: [
                                _buildCompanyStep(r),
                                _buildTanksStep(r),
                                _buildDispenserStep(r),
                                _buildProductsStep(r),
                                _buildPrinterStep(r),
                                _buildLicenseStep(r),
                                _buildAdminStep(r),
                              ],
                            ),
                        },
                      ),
                      const Divider(height: 1, color: AppColors.greyLight),
                      _buildFooter(r),
                    ],
                  ),
                ),
              );

              return Padding(
                padding: EdgeInsets.fromLTRB(r.w(8), r.h(6), r.w(8), r.h(6)),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: panel,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    if (_entry == _SetupEntry.landing) {
      return _buildEntryHeader(
        r,
        title: 'ยินดีต้อนรับ',
        subtitle: 'เลือกวิธีเริ่มต้นใช้งาน FUEL POS',
      );
    }
    if (_entry == _SetupEntry.importReview) {
      return _buildEntryHeader(
        r,
        title: 'นำเข้าฐานข้อมูล',
        subtitle: 'ตรวจสอบ schema ก่อนนำเข้า (v${DatabaseService.schemaVersion})',
      );
    }

    final meta = _meta(_currentStep);
    return Container(
      padding: EdgeInsets.fromLTRB(r.w(14), r.h(10), r.w(14), r.h(10)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E56A0), Color(0xFF163172)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppLogo(size: r.w(32)),
              SizedBox(width: r.w(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ตั้งค่าระบบครั้งแรก',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      meta.title,
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: r.sp(15),
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(10), vertical: r.h(4)),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '${_currentStep + 1} / $_totalSteps',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(10)),
          Row(
            children: List.generate(_totalSteps, (i) {
              final active = i == _currentStep;
              final done = i < _currentStep;
              final info = _WizardStepInfo.all[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
                  child: Column(
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.white
                              : done
                                  ? AppColors.white.withValues(alpha: 0.35)
                                  : AppColors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: active
                              ? Border.all(color: AppColors.white, width: 2)
                              : null,
                        ),
                        child: Icon(
                          info.icon,
                          size: 16,
                          color: active
                              ? AppColors.corporateBlue
                              : AppColors.white.withValues(
                                  alpha: done ? 0.95 : 0.55,
                                ),
                        ),
                      ),
                      if (active) ...[
                        SizedBox(height: r.h(3)),
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryHeader(
    Responsive r, {
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(r.w(14), r.h(10), r.w(14), r.h(10)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E56A0), Color(0xFF163172)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          AppLogo(size: r.w(32)),
          SizedBox(width: r.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: r.sp(16),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.82),
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Responsive r) {
    if (_entry == _SetupEntry.landing) {
      return const SizedBox.shrink();
    }
    if (_entry == _SetupEntry.importReview) {
      final canImport =
          _importReport?.ok == true && !_importBusy && _importFilePath != null;
      return Padding(
        padding: EdgeInsets.fromLTRB(r.w(12), r.h(8), r.w(12), r.h(10)),
        child: Row(
          children: [
            Expanded(
              child: _WizardBtn(
                label: 'ย้อนกลับ',
                outline: true,
                onPressed: _importBusy
                    ? null
                    : () => setState(() {
                          _entry = _SetupEntry.landing;
                          _importFilePath = null;
                          _importFileName = null;
                          _importReport = null;
                        }),
              ),
            ),
            SizedBox(width: r.w(8)),
            Expanded(
              flex: 2,
              child: _WizardBtn(
                label: _importBusy ? 'กำลังนำเข้า...' : 'นำเข้าข้อมูล',
                onPressed: canImport ? _confirmImportDatabase : null,
              ),
            ),
          ],
        ),
      );
    }

    final onLicense = _currentStep == _licenseStepIndex;
    final canNext = !onLicense || _licenseVerified;

    return Padding(
      padding: EdgeInsets.fromLTRB(r.w(12), r.h(8), r.w(12), r.h(10)),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: _WizardBtn(
                label: 'ย้อนกลับ',
                outline: true,
                onPressed: _prev,
              ),
            ),
          if (_currentStep > 0) SizedBox(width: r.w(8)),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: _WizardBtn(
              label: _currentStep == _totalSteps - 1 ? 'เริ่มใช้งาน' : 'ถัดไป',
              onPressed: canNext ? _next : null,
            ),
          ),
        ],
      ),
    );
  }

  // ——— Landing / Import ———

  Widget _buildLandingStep(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'เริ่มต้นใช้งานระบบ',
            style: TextStyle(
              fontSize: r.sp(15),
              fontWeight: FontWeight.w900,
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(4)),
          Text(
            'ตั้งค่าสถานีใหม่ หรือนำเข้าฐานข้อมูลสำรอง (.db) จากเครื่องเดิม',
            style: TextStyle(
              fontSize: r.sp(11),
              color: AppColors.greyMedium,
            ),
          ),
          SizedBox(height: r.h(14)),
          _SetupChoiceCard(
            icon: Icons.auto_fix_high_rounded,
            title: 'ตั้งค่าใหม่',
            subtitle: 'Wizard 7 ขั้นตอน — สถานี, ถัง, ตู้จ่าย, License',
            color: AppColors.corporateBlue,
            onTap: _startNewSetup,
          ),
          SizedBox(height: r.h(10)),
          _SetupChoiceCard(
            icon: Icons.upload_file_rounded,
            title: 'นำเข้าฐานข้อมูล',
            subtitle:
                'เลือกไฟล์ .db — ตรวจ schema ให้ตรง v${DatabaseService.schemaVersion} ก่อนนำเข้า',
            color: AppColors.fuelBenzene,
            onTap: _pickImportDatabase,
          ),
          SizedBox(height: r.h(12)),
          Container(
            padding: EdgeInsets.all(r.w(10)),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(r.r(10)),
              border: Border.all(color: AppColors.greyLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: r.sp(16), color: AppColors.corporateBlue),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Text(
                    'ไฟล์สำรองต้องเป็นฐานข้อมูล FUEL POS และ schema ต้องไม่ใหม่กว่าแอป '
                    '(ปัจจุบัน v${DatabaseService.schemaVersion}) — ระบบจะ migrate อัตโนมัติหากเป็นเวอร์ชันเก่า',
                    style: TextStyle(
                      fontSize: r.sp(10),
                      color: AppColors.greyDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportReviewStep(Responsive r) {
    final report = _importReport;
    final ok = report?.ok == true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(r.w(12)),
            decoration: BoxDecoration(
              color: ok
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.r(10)),
              border: Border.all(
                color: ok ? AppColors.success : AppColors.danger,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: ok ? AppColors.success : AppColors.danger,
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Text(
                    report?.message ?? 'กำลังตรวจสอบ...',
                    style: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w700,
                      color: ok ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(12)),
          _ImportInfoRow(
            label: 'ไฟล์',
            value: _importFileName ?? '-',
            r: r,
          ),
          _ImportInfoRow(
            label: 'Schema',
            value: report?.versionLabel ?? '-',
            r: r,
          ),
          _ImportInfoRow(
            label: 'สถานี',
            value: report?.stationName?.trim().isNotEmpty == true
                ? report!.stationName!
                : '(ไม่ระบุ)',
            r: r,
          ),
          _ImportInfoRow(
            label: 'ผู้ใช้ในระบบ',
            value: '${report?.userCount ?? 0} คน',
            r: r,
          ),
          _ImportInfoRow(
            label: 'ตั้งค่าแล้ว',
            value: report?.isInitialized == true ? 'ใช่' : 'ยังไม่ครบ',
            r: r,
          ),
          if (report != null && report.missingTables.isNotEmpty) ...[
            SizedBox(height: r.h(8)),
            Text(
              'ตารางที่ขาด: ${report.missingTables.join(', ')}',
              style: TextStyle(
                fontSize: r.sp(10),
                color: AppColors.danger,
              ),
            ),
          ],
          SizedBox(height: r.h(12)),
          OutlinedButton.icon(
            onPressed: _importBusy ? null : _pickImportDatabase,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('เลือกไฟล์อื่น'),
          ),
        ],
      ),
    );
  }

  // ——— Step 1 ———
  Widget _buildCompanyStep(Responsive r) {
    return _StepFrame(
      step: 0,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 480;
          final gap = SizedBox(height: r.h(8));
          final gapW = SizedBox(width: r.w(10));

          Widget legalSection() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionLabel(
                    icon: Icons.corporate_fare_rounded,
                    title: 'ข้อมูลนิติบุคคล',
                    hint: 'แสดงบนใบกำกับภาษีเต็มรูป',
                  ),
                  gap,
                  Row(
                    children: [
                      Expanded(
                        child: _CompactField(
                          label: 'ชื่อบริษัท / สถานี',
                          controller: _companyCtrl,
                          icon: Icons.storefront_outlined,
                          required: true,
                        ),
                      ),
                      gapW,
                      Expanded(
                        child: _CompactField(
                          label: 'เลขประจำตัวผู้เสียภาษี',
                          controller: _taxIdCtrl,
                          icon: Icons.numbers_rounded,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  gap,
                  _CompactField(
                    label: 'ที่อยู่ (สำหรับใบกำกับภาษี)',
                    controller: _addressCtrl,
                    icon: Icons.location_on_outlined,
                  ),
                  gap,
                  Row(
                    children: [
                      Expanded(
                        child: _CompactField(
                          label: 'เบอร์ติดต่อ',
                          controller: _phoneCtrl,
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                        ),
                      ),
                      gapW,
                      Expanded(
                        child: _CompactToggle(
                          label: 'ราคาขายรวม VAT',
                          subtitle: 'ราคาตั้งค่ารวมภาษีแล้ว',
                          value: _vatInclusive,
                          onChanged: (v) => setState(() => _vatInclusive = v),
                        ),
                      ),
                    ],
                  ),
                ],
              );

          Widget receiptSection() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionLabel(
                    icon: Icons.receipt_long_rounded,
                    title: 'ใบเสร็จ & แบรนด์',
                    hint: 'ข้อความท้ายใบและโลโก้สถานี',
                  ),
                  gap,
                  _CompactField(
                    label: 'ข้อความท้ายใบเสร็จ',
                    controller: _footerCtrl,
                    icon: Icons.format_quote_outlined,
                  ),
                  gap,
                  _LogoPickerCard(
                    logoPath: _logoPath,
                    onPick: _pickLogo,
                  ),
                ],
              );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: legalSection(),
                  ),
                ),
                gapW,
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: receiptSection(),
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [legalSection(), gap, receiptSection()],
            ),
          );
        },
      ),
    );
  }

  // ——— Step 2 ———
  Widget _buildTanksStep(Responsive r) {
    return _StepFrame(
      step: 1,
      child: Column(
        children: [
          _SegmentTabs(
            tabs: const [
              (Icons.water_drop_outlined, 'ประเภทน้ำมัน'),
              (Icons.storage_rounded, 'ถังเก็บ'),
            ],
            index: _step2Tab,
            onSelect: (i) => setState(() => _step2Tab = i),
          ),
          SizedBox(height: r.h(4)),
          Expanded(
            child: _step2Tab == 0
                ? _buildFuelList(r)
                : _buildTankList(r),
          ),
          SizedBox(height: r.h(4)),
          SizedBox(
            height: 32,
            child: _WizardBtn(
              label: _step2Tab == 0 ? '+ เพิ่มประเภทน้ำมัน' : '+ เพิ่มถัง',
              outline: true,
              icon: Icons.add_rounded,
              onPressed: _step2Tab == 0 ? _addFuelType : _addTank,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelList(Responsive r) {
    if (_fuelTypes.isEmpty) {
      return _EmptyState(
        icon: Icons.water_drop_outlined,
        title: 'ยังไม่มีประเภทน้ำมัน',
        actionLabel: 'เพิ่มประเภทแรก',
        onAction: _addFuelType,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _fuelTypes.length,
      separatorBuilder: (_, __) => SizedBox(height: r.h(4)),
      itemBuilder: (context, i) {
        return _FuelTypeRow(
          fuel: _fuelTypes[i],
          onChanged: (u) => setState(() => _fuelTypes[i] = u),
          onDelete: _fuelTypes.length > 1
              ? () => setState(() => _fuelTypes.removeAt(i))
              : null,
        );
      },
    );
  }

  Widget _buildTankList(Responsive r) {
    if (_tanks.isEmpty) {
      return _EmptyState(
        icon: Icons.storage_rounded,
        title: 'ยังไม่มีถังเก็บ',
        subtitle: 'กำหนดชนิดน้ำมันของแต่ละถัง',
        actionLabel: 'เพิ่มถังแรก',
        onAction: _addTank,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _tanks.length,
      separatorBuilder: (_, __) => SizedBox(height: r.h(4)),
      itemBuilder: (context, i) {
        return _TankRow(
          tank: _tanks[i],
          fuelTypes: _fuelTypes,
          fuelName: _fuelNameFor(_tanks[i]),
          fuelColor: _fuelColorFromHex(
            _fuelTypes.isNotEmpty
                ? _fuelTypes[_fuelIndexFor(_tanks[i])]['color_hex'] as String?
                : null,
          ),
          onDelete: () => setState(() => _tanks.removeAt(i)),
          onChanged: (u) => setState(() => _tanks[i] = u),
        );
      },
    );
  }

  // ——— Step 3 ———
  Widget _buildDispenserStep(Responsive r) {
    if (_dispensers.isEmpty) {
      return _StepFrame(
        step: 2,
        child: Center(
          child: _EmptyState(
            icon: Icons.local_gas_station_rounded,
            title: 'ยังไม่มีตู้จ่ายน้ำมัน',
            subtitle: 'เพิ่มตู้จ่ายแล้วกำหนดมือจ่ายให้เชื่อมกับถัง',
            actionLabel: 'เพิ่มตู้จ่ายแรก',
            onAction: _addDispenser,
          ),
        ),
      );
    }

    _dispenserIdx = _dispenserIdx.clamp(0, _dispensers.length - 1);
    final tankOptions = _tankSelectOptions();
    final d = _dispensers[_dispenserIdx];

    return _StepFrame(
      step: 2,
      child: Column(
        children: [
          _DispenserFlowStepper(subStep: _dispenserSubStep),
          SizedBox(height: r.h(8)),
          Expanded(
            child: _dispenserSubStep == 0
                ? _DispenserPickPanel(
                    dispensers: _dispensers,
                    onSelect: (i) => setState(() {
                      _dispenserIdx = i;
                      _dispenserSubStep = 1;
                    }),
                    onAdd: _dispensers.length < 8 ? _addDispenser : null,
                  )
                : _NozzleConfigurePanel(
                    dispenser: d,
                    tankOptions: tankOptions,
                    fuelColorFor: _tankFuelColor,
                    fuelShortNameFor: _tankFuelShortName,
                    onBack: () => setState(() => _dispenserSubStep = 0),
                    onUpdate: (u) =>
                        setState(() => _dispensers[_dispenserIdx] = u),
                    onDelete: _dispensers.length > 1
                        ? () => setState(() {
                              _dispensers.removeAt(_dispenserIdx);
                              _dispenserIdx = (_dispenserIdx - 1)
                                  .clamp(0, _dispensers.length - 1);
                              if (_dispensers.isEmpty) {
                                _dispenserSubStep = 0;
                              }
                            })
                        : null,
                  ),
          ),
        ],
      ),
    );
  }

  // ——— Step 4 ———
  Widget _buildProductsStep(Responsive r) {
    return _StepFrame(
      step: 3,
      child: Column(
        children: [
          const _InfoStrip(
            icon: Icons.tips_and_updates_outlined,
            text: 'เลือกได้ภายหลัง — เปิดใช้เมนูตะกร้าสินค้าในแดชบอร์ด',
            dense: true,
          ),
          SizedBox(height: r.h(8)),
          Expanded(
            child: Center(
              child: _ChoiceCards(
                yesTitle: 'เปิดขายสินค้า',
                yesDesc: 'น้ำดื่ม · ยาง · อะไหล่',
                noTitle: 'ไม่ขายสินค้า',
                noDesc: 'ขายเฉพาะน้ำมัน',
                value: _sellProducts,
                onChanged: (v) => setState(() => _sellProducts = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ——— Step 5 ———
  Widget _buildPrinterStep(Responsive r) {
    final devices = _pageSlice(_printerDevices, _printerPage);

    return _StepFrame(
      step: 4,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _WizardBtn(
                  label: 'ค้นหาเครื่องพิมพ์',
                  outline: true,
                  icon: Icons.bluetooth_searching_rounded,
                  loading: _printerScanning,
                  onPressed: _scanPrinters,
                ),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                child: _WizardBtn(
                  label: 'ข้ามขั้นตอน',
                  outline: true,
                  icon: Icons.skip_next_rounded,
                  onPressed: () => setState(() => _printerSkipped = true),
                ),
              ),
            ],
          ),
          if (_printerConnected)
            Padding(
              padding: EdgeInsets.only(top: r.h(6)),
              child: const _StatusChip(
                icon: Icons.check_circle_rounded,
                label: 'เชื่อมต่อเครื่องพิมพ์แล้ว',
                color: AppColors.success,
              ),
            )
          else if (_printerSkipped)
            Padding(
              padding: EdgeInsets.only(top: r.h(6)),
              child: const _StatusChip(
                icon: Icons.schedule_rounded,
                label: 'ตั้งค่าเครื่องพิมพ์ภายหลังได้',
                color: AppColors.corporateBlue,
              ),
            ),
          SizedBox(height: r.h(6)),
          Expanded(
            child: devices.isEmpty
                ? const _EmptyState(
                    icon: Icons.print_disabled_outlined,
                    title: 'ยังไม่พบเครื่องพิมพ์',
                    subtitle: 'เปิด Bluetooth และจับคู่เครื่องพิมพ์ก่อน',
                  )
                : Column(
                    children: devices.map((d) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: r.h(3)),
                          child: _PrinterTile(
                            name: d.name ?? d.address,
                            address: d.address,
                            onConnect: () => _connectPrinter(d),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          if (_printerDevices.isNotEmpty)
            _ListPager(
              page: _printerPage,
              total: _pageCount(_printerDevices.length),
              onPrev: _printerPage > 0
                  ? () => setState(() => _printerPage--)
                  : null,
              onNext: _printerPage < _pageCount(_printerDevices.length) - 1
                  ? () => setState(() => _printerPage++)
                  : null,
            ),
        ],
      ),
    );
  }

  // ——— Step 6 ———
  Widget _buildLicenseStep(Responsive r) {
    return _StepFrame(
      step: 5,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AlertBanner(
            icon: Icons.shield_outlined,
            text: 'บังคับยืนยัน — ออกก่อนยืนยันจะบันทึก draft แล้วปิดแอป',
            tone: _AlertTone.warning,
            dense: true,
          ),
          SizedBox(height: r.h(8)),
          _LicenseKeyField(controller: _licenseCtrl),
          SizedBox(height: r.h(8)),
          _WizardBtn(
            label: 'ยืนยัน License',
            icon: Icons.verified_user_rounded,
            loading: _verifyingLicense,
            onPressed: _verifyLicense,
          ),
          if (_licenseVerified) ...[
            SizedBox(height: r.h(8)),
            _LicenseSuccessCard(customerName: _licenseCustomerName),
          ],
        ],
          ),
        ),
      ),
    );
  }

  // ——— Step 7 ———
  Widget _buildAdminStep(Responsive r) {
    return _StepFrame(
      step: 6,
      child: LayoutBuilder(
        builder: (context, c) {
          final gap = SizedBox(height: r.h(8));
          final gapW = SizedBox(width: r.w(10));
          final fields = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel(
                icon: Icons.admin_panel_settings_outlined,
                title: 'บัญชีผู้ดูแลระบบ',
                hint: 'ใช้เข้าสู่ระบบและตั้งค่าระบบทั้งหมด',
              ),
              gap,
              if (c.maxWidth > 520)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CompactField(
                        label: 'ชื่อผู้ใช้',
                        controller: _adminUserCtrl,
                        icon: Icons.person_outline_rounded,
                        required: true,
                      ),
                    ),
                    gapW,
                    Expanded(
                      child: _CompactField(
                        label: 'รหัสผ่าน',
                        controller: _adminPassCtrl,
                        icon: Icons.lock_outline_rounded,
                        obscure: true,
                      ),
                    ),
                    gapW,
                    Expanded(
                      child: _CompactField(
                        label: 'ยืนยันรหัสผ่าน',
                        controller: _adminPassConfirmCtrl,
                        icon: Icons.lock_reset_rounded,
                        obscure: true,
                      ),
                    ),
                  ],
                )
              else ...[
                _CompactField(
                  label: 'ชื่อผู้ใช้',
                  controller: _adminUserCtrl,
                  icon: Icons.person_outline_rounded,
                  required: true,
                ),
                gap,
                _CompactField(
                  label: 'รหัสผ่าน (อย่างน้อย 4 ตัว)',
                  controller: _adminPassCtrl,
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                ),
                gap,
                _CompactField(
                  label: 'ยืนยันรหัสผ่าน',
                  controller: _adminPassConfirmCtrl,
                  icon: Icons.lock_reset_rounded,
                  obscure: true,
                ),
              ],
              gap,
              const _InfoStrip(
                icon: Icons.security_rounded,
                text: 'เก็บรหัสผ่านเป็นความลับ — สามารถเปลี่ยนได้ในหน้าตั้งค่า',
              ),
            ],
            ),
          );
          return Align(alignment: Alignment.topCenter, child: fields);
        },
      ),
    );
  }
}

// ——— Setup entry / import helpers ———

class _SetupChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SetupChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(r.r(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.r(12)),
        child: Container(
          padding: EdgeInsets.all(r.w(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.r(12)),
            border: Border.all(color: AppColors.greyLight),
          ),
          child: Row(
            children: [
              Container(
                width: r.w(44),
                height: r.w(44),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(r.r(10)),
                ),
                child: Icon(icon, color: color, size: r.sp(22)),
              ),
              SizedBox(width: r.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: r.sp(14),
                        fontWeight: FontWeight.w900,
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                    SizedBox(height: r.h(2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: r.sp(10),
                        color: AppColors.greyMedium,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.greyMedium, size: r.sp(22)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Responsive r;

  const _ImportInfoRow({
    required this.label,
    required this.value,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.w(90),
            child: Text(
              label,
              style: TextStyle(
                fontSize: r.sp(11),
                color: AppColors.greyMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: r.sp(11),
                color: AppColors.corporateBlueDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ——— Professional wizard UI ———

class _WizardStepInfo {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WizardStepInfo(this.icon, this.title, this.subtitle);

  static const all = [
    _WizardStepInfo(Icons.storefront_rounded, 'ข้อมูลสถานี',
        'นิติบุคคล · ใบกำกับภาษี · ใบเสร็จ'),
    _WizardStepInfo(Icons.propane_rounded, 'ถังน้ำมัน',
        'ประเภทน้ำมัน · ความจุ · คงเหลือ'),
    _WizardStepInfo(Icons.local_gas_station_rounded, 'ตู้จ่ายน้ำมัน',
        'ตู้จ่าย · มือจ่าย · ผูกถัง'),
    _WizardStepInfo(Icons.shopping_bag_rounded, 'สินค้าทั่วไป',
        'เมนูขายสินค้าเสริม'),
    _WizardStepInfo(Icons.print_rounded, 'เครื่องพิมพ์',
        'Bluetooth ใบเสร็จ'),
    _WizardStepInfo(Icons.verified_user_rounded, 'License',
        'Product Key'),
    _WizardStepInfo(Icons.admin_panel_settings_rounded, 'ผู้ดูแลระบบ',
        'บัญชีแรกเข้า'),
  ];
}

enum _AlertTone { info, warning, success }

class _StepFrame extends StatelessWidget {
  final int step;
  final Widget child;

  const _StepFrame({
    required this.step,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final meta = _WizardStepInfo.all[step];
    final bodyPad = EdgeInsets.fromLTRB(r.w(14), r.h(4), r.w(14), r.h(6));

    Widget header() {
      return Padding(
        padding: EdgeInsets.fromLTRB(r.w(14), r.h(10), r.w(14), 0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E56A0), Color(0xFF3AB0FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.corporateBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(meta.icon, color: AppColors.white, size: 22),
            ),
            SizedBox(width: r.w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.title,
                    style: TextStyle(
                      color: AppColors.corporateBlueDark,
                      fontSize: r.sp(14),
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.h(2)),
                  Text(
                    meta.subtitle,
                    style: TextStyle(
                      color: AppColors.greyMedium,
                      fontSize: r.sp(10),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(),
        Padding(
          padding: EdgeInsets.fromLTRB(r.w(14), r.h(8), r.w(14), 0),
          child: Container(height: 1, color: AppColors.greyLight),
        ),
        Expanded(child: Padding(padding: bodyPad, child: child)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.corporateBlue),
        SizedBox(width: r.w(6)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w800,
                  color: AppColors.corporateBlueDark,
                ),
              ),
              Text(
                hint,
                style: TextStyle(
                  fontSize: r.sp(9),
                  color: AppColors.greyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dense;

  const _InfoStrip({
    required this.icon,
    required this.text,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(10),
        vertical: dense ? r.h(5) : r.h(6),
      ),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.corporateBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.corporateBlue),
          SizedBox(width: r.w(8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: r.sp(9),
                color: AppColors.corporateBlueDark,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final _AlertTone tone;
  final bool dense;

  const _AlertBanner({
    required this.icon,
    required this.text,
    this.tone = _AlertTone.info,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final Color bg;
    final Color fg;
    final Color border;
    switch (tone) {
      case _AlertTone.warning:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = const Color(0xFF856404);
        border = AppColors.warning.withValues(alpha: 0.5);
      case _AlertTone.success:
        bg = AppColors.success.withValues(alpha: 0.1);
        fg = AppColors.success;
        border = AppColors.success.withValues(alpha: 0.35);
      case _AlertTone.info:
        bg = AppColors.lightBlue.withValues(alpha: 0.5);
        fg = AppColors.corporateBlueDark;
        border = AppColors.corporateBlue.withValues(alpha: 0.2);
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(10),
        vertical: dense ? r.h(5) : r.h(8),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          SizedBox(width: r.w(8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: r.sp(9),
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(6)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: r.w(6)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool obscure;
  final bool required;
  final TextInputType? keyboard;

  const _CompactField({
    required this.label,
    required this.controller,
    this.icon,
    this.obscure = false,
    this.required = false,
    this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return SizedBox(
      height: r.h(44).clamp(40.0, 48.0),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        maxLines: 1,
        style: TextStyle(
          color: AppColors.black,
          fontSize: r.sp(12),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          labelText: required ? '$label *' : label,
          labelStyle: TextStyle(
            color: AppColors.greyMedium,
            fontSize: r.sp(10),
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: AppColors.corporateBlue)
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          filled: true,
          fillColor: AppColors.softWhite,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.greyLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.greyLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: AppColors.corporateBlue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoPickerCard extends StatelessWidget {
  final String? logoPath;
  final VoidCallback onPick;

  const _LogoPickerCard({required this.logoPath, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final hasLogo = logoPath != null;
    return Material(
      color: AppColors.softWhite,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(r.w(10)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasLogo
                  ? AppColors.corporateBlue.withValues(alpha: 0.4)
                  : AppColors.greyLight,
              width: hasLogo ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasLogo
                    ? Image.file(
                        File(logoPath!),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        color: AppColors.lightBlue,
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.corporateBlue,
                          size: 26,
                        ),
                      ),
              ),
              SizedBox(width: r.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLogo ? 'เปลี่ยนโลโก้สถานี' : 'อัปโหลดโลโก้สถานี',
                      style: TextStyle(
                        fontSize: r.sp(11),
                        fontWeight: FontWeight.w800,
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                    Text(
                      'PNG / JPG จากแกลเลอรี',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        color: AppColors.greyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.corporateBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LicenseKeyField extends StatelessWidget {
  final TextEditingController controller;

  const _LicenseKeyField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Product Key',
          style: TextStyle(
            fontSize: r.sp(10),
            fontWeight: FontWeight.w700,
            color: AppColors.greyDark,
          ),
        ),
        SizedBox(height: r.h(4)),
        SizedBox(
          height: r.h(48).clamp(44.0, 52.0),
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: r.sp(13),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.corporateBlueDark,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: AppColors.greyMedium,
                fontSize: r.sp(11),
                letterSpacing: 0.8,
              ),
              prefixIcon: const Icon(
                Icons.vpn_key_rounded,
                color: AppColors.corporateBlue,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.softWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.greyLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.greyLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.corporateBlue,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LicenseSuccessCard extends StatelessWidget {
  final String? customerName;

  const _LicenseSuccessCard({this.customerName});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.all(r.w(12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.12),
            AppColors.success.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 24),
          ),
          SizedBox(width: r.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ยืนยัน License สำเร็จ',
                  style: TextStyle(
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                if (customerName != null && customerName!.isNotEmpty)
                  Text(
                    customerName!,
                    style: TextStyle(
                      fontSize: r.sp(10),
                      color: AppColors.greyDark,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 100;

        if (tight) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.w(8)),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: AppColors.corporateBlue),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w700,
                        color: AppColors.corporateBlueDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onAction != null)
                    Material(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: AppColors.corporateBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.corporateBlue),
            ),
            SizedBox(height: r.h(8)),
            Text(
              title,
              style: TextStyle(
                fontSize: r.sp(12),
                fontWeight: FontWeight.w800,
                color: AppColors.corporateBlueDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: r.h(4)),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: r.sp(9),
                  color: AppColors.greyMedium,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: r.h(8)),
              SizedBox(
                width: 180,
                child: _WizardBtn(
                  label: actionLabel!,
                  icon: Icons.add_rounded,
                  onPressed: onAction,
                ),
              ),
            ],
          ],
        );

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: content,
          ),
        );
      },
    );
  }
}

class _WizardBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outline;
  final IconData? icon;
  final bool loading;

  const _WizardBtn({
    required this.label,
    this.onPressed,
    this.outline = false,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final enabled = onPressed != null && !loading;

    return SizedBox(
      height: r.h(42).clamp(38.0, 44.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: outline || !enabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF1E56A0), Color(0xFF163172)],
                ),
          border: outline
              ? Border.all(
                  color: enabled
                      ? AppColors.corporateBlue
                      : AppColors.greyLight,
                  width: 1.5,
                )
              : null,
          color: outline
              ? AppColors.white
              : (enabled ? null : AppColors.greyLight),
          boxShadow: enabled && !outline
              ? [
                  BoxShadow(
                    color: AppColors.corporateBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 18,
                            color: outline
                                ? AppColors.corporateBlue
                                : AppColors.white,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: outline
                                ? AppColors.corporateBlue
                                : AppColors.white,
                            fontSize: r.sp(11),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  final List<(IconData, String)> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  const _SegmentTabs({
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == index;
          final (icon, label) = tabs[i];
          return Expanded(
            child: Material(
              color: sel ? AppColors.corporateBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: r.h(36).clamp(32.0, 38.0),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: sel ? AppColors.white : AppColors.greyMedium,
                      ),
                      SizedBox(width: r.w(4)),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: r.sp(10),
                          fontWeight: FontWeight.w700,
                          color: sel ? AppColors.white : AppColors.greyDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ListPager extends StatelessWidget {
  final int page;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ListPager({
    required this.page,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return SizedBox(
      height: r.h(34).clamp(30.0, 36.0),
      child: Row(
        children: [
          _IconBtn(icon: Icons.chevron_left, onTap: onPrev),
          Expanded(
            child: Text(
              '${page + 1} / $total',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.sp(10),
                color: AppColors.greyDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _IconBtn(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.softWhite : AppColors.greyLight,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.greyDark : AppColors.greyMedium,
          ),
        ),
      ),
    );
  }
}

class _CompactToggle extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactToggle({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      height: r.h(44).clamp(40.0, 48.0),
      padding: EdgeInsets.symmetric(horizontal: r.w(10)),
      decoration: BoxDecoration(
        color: value
            ? AppColors.lightBlue.withValues(alpha: 0.4)
            : AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? AppColors.corporateBlue.withValues(alpha: 0.4)
              : AppColors.greyLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.percent_rounded,
            size: 18,
            color: value ? AppColors.corporateBlue : AppColors.greyMedium,
          ),
          SizedBox(width: r.w(8)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: r.sp(10),
                    fontWeight: FontWeight.w700,
                    color: AppColors.corporateBlueDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: r.sp(8),
                      color: AppColors.greyMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.corporateBlue,
          ),
        ],
      ),
    );
  }
}

class _ChoiceCards extends StatelessWidget {
  final String yesTitle;
  final String yesDesc;
  final String noTitle;
  final String noDesc;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ChoiceCards({
    required this.yesTitle,
    required this.yesDesc,
    required this.noTitle,
    required this.noDesc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? (constraints.maxHeight * 0.92).clamp(72.0, 96.0)
            : r.h(88).clamp(72.0, 96.0);

        Widget card({
      required bool selected,
      required bool yes,
      required IconData icon,
      required String title,
      required String desc,
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(yes),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: cardH,
              padding: EdgeInsets.symmetric(
                horizontal: r.w(10),
                vertical: r.h(8),
              ),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF1E56A0), Color(0xFF163172)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected ? null : AppColors.softWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.corporateBlue
                      : AppColors.greyLight,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:
                              AppColors.corporateBlue.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? AppColors.white : AppColors.greyMedium,
                  ),
                  SizedBox(height: r.h(4)),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.sp(10),
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.white : AppColors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.sp(8),
                      color: selected
                          ? AppColors.white.withValues(alpha: 0.85)
                          : AppColors.greyMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          selected: value,
          yes: true,
          icon: Icons.shopping_cart_rounded,
          title: yesTitle,
          desc: yesDesc,
        ),
        SizedBox(width: r.w(10)),
        card(
          selected: !value,
          yes: false,
          icon: Icons.local_gas_station_rounded,
          title: noTitle,
          desc: noDesc,
        ),
      ],
    );
      },
    );
  }
}

class _PrinterTile extends StatelessWidget {
  final String name;
  final String address;
  final VoidCallback onConnect;

  const _PrinterTile({
    required this.name,
    required this.address,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(8)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greyLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.print_rounded,
              size: 20,
              color: AppColors.corporateBlue,
            ),
          ),
          SizedBox(width: r.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: r.sp(9),
                    color: AppColors.greyMedium,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _WizardBtn(
            label: 'เชื่อมต่อ',
            outline: true,
            onPressed: onConnect,
          ),
        ],
      ),
    );
  }
}

class _DispenserFlowStepper extends StatelessWidget {
  final int subStep;

  const _DispenserFlowStepper({required this.subStep});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    Widget stepNode({
      required int number,
      required String label,
      required bool active,
      required bool done,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || done
                  ? AppColors.corporateBlue
                  : AppColors.greyLight,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.corporateBlue.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: r.sp(11),
                      fontWeight: FontWeight.w900,
                      color: active
                          ? AppColors.white
                          : AppColors.greyMedium,
                    ),
                  ),
          ),
          SizedBox(width: r.w(6)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active
                  ? AppColors.corporateBlueDark
                  : AppColors.greyMedium,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.w(4)),
      child: Row(
        children: [
          stepNode(
            number: 1,
            label: 'ตู้จ่าย',
            active: subStep == 0,
            done: subStep == 1,
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: r.w(10)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.corporateBlue.withValues(alpha: 0.35),
                    subStep == 1
                        ? AppColors.corporateBlue
                        : AppColors.greyLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          stepNode(
            number: 2,
            label: 'มือจ่าย',
            active: subStep == 1,
            done: false,
          ),
        ],
      ),
    );
  }
}

class _DispenserPickPanel extends StatelessWidget {
  final List<Map<String, dynamic>> dispensers;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;

  const _DispenserPickPanel({
    required this.dispensers,
    required this.onSelect,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final itemCount = dispensers.length + (onAdd != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.touch_app_outlined,
                size: 16, color: AppColors.corporateBlue),
            SizedBox(width: r.w(6)),
            Expanded(
              child: Text(
                'แตะตู้จ่ายเพื่อไปขั้นถัดไป',
                style: TextStyle(
                  fontSize: r.sp(10),
                  color: AppColors.greyMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.h(8)),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: r.h(10),
              crossAxisSpacing: r.w(10),
              childAspectRatio: 1.45,
            ),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (onAdd != null && i == dispensers.length) {
                return _AddDispenserCard(onTap: onAdd!);
              }
              final d = dispensers[i];
              return _DispenserGridCard(
                name: d['name']?.toString() ?? 'ตู้จ่าย ${i + 1}',
                nozzleCount: (d['nozzles'] as List?)?.length ?? 0,
                onTap: () => onSelect(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DispenserGridCard extends StatelessWidget {
  final String name;
  final int nozzleCount;
  final VoidCallback onTap;

  const _DispenserGridCard({
    required this.name,
    required this.nozzleCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.greyLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.corporateBlue.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(r.w(10)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.corporateBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_gas_station_rounded,
                        size: 22,
                        color: AppColors.corporateBlue,
                      ),
                    ),
                    const Spacer(),
                    if (nozzleCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.greyLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.water_drop_outlined,
                                size: 11, color: AppColors.corporateBlue),
                            const SizedBox(width: 3),
                            Text(
                              '$nozzleCount',
                              style: TextStyle(
                                fontSize: r.sp(9),
                                fontWeight: FontWeight.w800,
                                color: AppColors.corporateBlueDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.w800,
                    color: AppColors.corporateBlueDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ตั้งค่ามือจ่าย',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        color: AppColors.greyMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.corporateBlue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDispenserCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddDispenserCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Material(
      color: AppColors.softWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.corporateBlue.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.corporateBlue.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 26, color: AppColors.corporateBlue),
              ),
              SizedBox(height: r.h(6)),
              Text(
                'เพิ่มตู้จ่าย',
                style: TextStyle(
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w700,
                  color: AppColors.corporateBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NozzleConfigurePanel extends StatelessWidget {
  final Map<String, dynamic> dispenser;
  final List<Map<String, String>> tankOptions;
  final Color Function(String tankName) fuelColorFor;
  final String Function(String tankName) fuelShortNameFor;
  final VoidCallback onBack;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final VoidCallback? onDelete;

  const _NozzleConfigurePanel({
    required this.dispenser,
    required this.tankOptions,
    required this.fuelColorFor,
    required this.fuelShortNameFor,
    required this.onBack,
    required this.onUpdate,
    this.onDelete,
  });

  List<String> get _tankNames =>
      tankOptions.map((t) => t['name'] ?? '').toList();

  Future<void> _editNozzle(
    BuildContext context, {
    required int index,
    required Map<String, dynamic> nozzle,
    required List<Map<String, dynamic>> nozzles,
  }) async {
    final names = _tankNames;
    if (names.isEmpty) return;

    var selected = names.contains(nozzle['tank_name'] as String? ?? '')
        ? nozzle['tank_name'] as String
        : names.first;
    final number = nozzle['number'] as int? ?? index + 1;

    await HighEndDialog.show(
      context: context,
      title: 'มือจ่ายหัวที่ $number',
      icon: Icons.water_drop_rounded,
      compact: true,
      maxWidth: 420,
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_rounded,
                    size: 16, color: AppColors.corporateBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'เลือกถังที่ผูกมือจ่าย — แสดงชนิดน้ำมัน',
                    style: TextStyle(
                      fontSize: Responsive.of(ctx).sp(9),
                      color: AppColors.greyMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...tankOptions.map((t) {
              final name = t['name'] ?? '';
              final isSel = selected == name;
              final color = fuelColorFor(name);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: isSel
                      ? AppColors.corporateBlue.withValues(alpha: 0.08)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setLocal(() => selected = name),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSel
                              ? AppColors.corporateBlue
                              : AppColors.greyLight,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.propane_tank_outlined,
                              size: 18, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['label'] ?? name,
                                  style: TextStyle(
                                    fontSize: Responsive.of(ctx).sp(10),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'ชนิดน้ำมัน: ${t['fuel'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: Responsive.of(ctx).sp(8),
                                    color: AppColors.corporateBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: AppColors.corporateBlue),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        if (nozzles.length > 1)
          PrimaryButton(
            label: 'ลบหัวจ่าย',
            variant: ButtonVariant.outline,
            expand: false,
            onPressed: () {
              final list = List<Map<String, dynamic>>.from(nozzles)
                ..removeAt(index);
              for (var i = 0; i < list.length; i++) {
                list[i] = {...list[i], 'number': i + 1};
              }
              onUpdate({...dispenser, 'nozzles': list});
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          expand: false,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        PrimaryButton(
          label: 'บันทึก',
          expand: false,
          onPressed: () {
            final list = List<Map<String, dynamic>>.from(nozzles);
            list[index] = {...nozzle, 'tank_name': selected};
            onUpdate({...dispenser, 'nozzles': list});
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final nozzles = List<Map<String, dynamic>>.from(
      (dispenser['nozzles'] as List?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          [],
    );
    final name = dispenser['name']?.toString() ?? 'ตู้จ่าย';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.corporateBlueDark),
              onPressed: onBack,
              tooltip: 'กลับเลือกตู้จ่าย',
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.corporateBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_gas_station_rounded,
                  size: 20, color: AppColors.corporateBlue),
            ),
            SizedBox(width: r.w(8)),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: r.sp(14),
                  fontWeight: FontWeight.w800,
                  color: AppColors.corporateBlueDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.w(10), vertical: r.h(4)),
              decoration: BoxDecoration(
                color: AppColors.corporateBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop_rounded,
                      size: 14, color: AppColors.corporateBlue),
                  SizedBox(width: r.w(4)),
                  Text(
                    '${nozzles.length} หัว',
                    style: TextStyle(
                      fontSize: r.sp(10),
                      fontWeight: FontWeight.w800,
                      color: AppColors.corporateBlue,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.danger),
                onPressed: onDelete,
                tooltip: 'ลบตู้จ่าย',
              ),
          ],
        ),
        SizedBox(height: r.h(8)),
        Expanded(
          child: nozzles.isEmpty
              ? _EmptyState(
                  icon: Icons.water_drop_outlined,
                  title: 'ยังไม่มีมือจ่าย',
                  subtitle: 'กดปุ่มด้านล่างเพื่อเพิ่มหัวจ่าย',
                  actionLabel: '+ เพิ่มมือจ่ายแรก',
                  onAction: _tankNames.isEmpty
                      ? null
                      : () {
                          onUpdate({
                            ...dispenser,
                            'nozzles': [
                              {
                                'number': 1,
                                'tank_name': _tankNames.first,
                              },
                            ],
                          });
                        },
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: r.h(10),
                    crossAxisSpacing: r.w(10),
                    childAspectRatio: 1.15,
                  ),
                  itemCount: nozzles.length,
                  itemBuilder: (context, index) {
                    final n = nozzles[index];
                    final tankName = n['tank_name'] as String? ?? '';
                    return _NozzleGridCard(
                      number: n['number'] as int? ?? index + 1,
                      fuelLabel: fuelShortNameFor(tankName),
                      fuelColor: fuelColorFor(tankName),
                      tankLabel: tankName,
                      onTap: () => _editNozzle(
                        context,
                        index: index,
                        nozzle: n,
                        nozzles: nozzles,
                      ),
                    );
                  },
                ),
        ),
        SizedBox(height: r.h(6)),
        SizedBox(
          height: r.h(36).clamp(32.0, 40.0),
          child: _WizardBtn(
            label: '+ เพิ่มมือจ่าย',
            outline: true,
            icon: Icons.add_rounded,
            onPressed: _tankNames.isEmpty
                ? null
                : () {
                    final list = List<Map<String, dynamic>>.from(nozzles)
                      ..add({
                        'number': nozzles.length + 1,
                        'tank_name': _tankNames.first,
                      });
                    onUpdate({...dispenser, 'nozzles': list});
                  },
          ),
        ),
      ],
    );
  }
}

class _NozzleGridCard extends StatelessWidget {
  final int number;
  final String fuelLabel;
  final Color fuelColor;
  final String tankLabel;
  final VoidCallback onTap;

  const _NozzleGridCard({
    required this.number,
    required this.fuelLabel,
    required this.fuelColor,
    required this.tankLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.greyLight),
            boxShadow: [
              BoxShadow(
                color: fuelColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fuelColor,
                  boxShadow: [
                    BoxShadow(
                      color: fuelColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: r.sp(18),
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ),
                ),
              ),
              SizedBox(height: r.h(8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop_rounded, size: 14, color: fuelColor),
                  const SizedBox(width: 4),
                  Text(
                    fuelLabel,
                    style: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w800,
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(4)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.w(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.propane_tank_outlined,
                        size: 12, color: AppColors.greyMedium),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        tankLabel,
                        style: TextStyle(
                          fontSize: r.sp(8),
                          color: AppColors.greyMedium,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.h(4)),
              Icon(Icons.edit_outlined,
                  size: 14, color: AppColors.corporateBlue.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuelTypeRow extends StatefulWidget {
  final Map<String, dynamic> fuel;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onDelete;

  const _FuelTypeRow({
    required this.fuel,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_FuelTypeRow> createState() => _FuelTypeRowState();
}

class _FuelTypeRowState extends State<_FuelTypeRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.fuel['name']?.toString() ?? '');
    _priceCtrl = TextEditingController(
        text: (widget.fuel['price'] as num?)?.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged({
      ...widget.fuel,
      'name': _nameCtrl.text,
      'price': double.tryParse(_priceCtrl.text) ?? 0,
    });
  }

  Color _fuelColor() {
    try {
      final hex =
          (widget.fuel['color_hex'] as String?)?.replaceFirst('#', '') ??
              '163172';
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.corporateBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: _fuelColor(),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _nameCtrl,
              style: TextStyle(
                fontSize: r.sp(11),
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'ชื่อน้ำมัน',
                labelStyle: TextStyle(fontSize: r.sp(9)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                border: InputBorder.none,
              ),
              onChanged: (_) => _emit(),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: r.sp(11),
                fontWeight: FontWeight.w700,
                color: AppColors.corporateBlue,
              ),
              decoration: InputDecoration(
                isDense: true,
                labelText: '฿/ลิตร',
                labelStyle: TextStyle(fontSize: r.sp(9)),
                prefixText: '฿ ',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                border: InputBorder.none,
              ),
              onChanged: (_) => _emit(),
            ),
          ),
          if (widget.onDelete != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.danger),
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}

class _TankRow extends StatelessWidget {
  final Map<String, dynamic> tank;
  final List<Map<String, dynamic>> fuelTypes;
  final String fuelName;
  final Color fuelColor;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _TankRow({
    required this.tank,
    required this.fuelTypes,
    required this.fuelName,
    required this.fuelColor,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final cap = (tank['capacity'] as num?)?.toDouble() ?? 1;
    final cur = (tank['current_liters'] as num?)?.toDouble() ?? 0;
    final pct = cap > 0 ? (cur / cap).clamp(0.0, 1.0) : 0.0;
    var fuelIdx = 0;
    for (var i = 0; i < fuelTypes.length; i++) {
      if (fuelTypes[i]['id'] == tank['fuel_type_id']) {
        fuelIdx = i;
        break;
      }
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: fuelColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tank['name']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: r.sp(10),
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 3,
                          backgroundColor: AppColors.greyLight,
                          color: pct < 0.2
                              ? AppColors.danger
                              : AppColors.corporateBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${cur.toStringAsFixed(0)}/${cap.toStringAsFixed(0)} ล.',
                      style: TextStyle(
                        fontSize: r.sp(8),
                        color: AppColors.greyMedium,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: fuelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              fuelName,
              style: TextStyle(
                fontSize: r.sp(8),
                fontWeight: FontWeight.w700,
                color: AppColors.corporateBlueDark,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.corporateBlue),
            onPressed: () => _editTankDialog(context, fuelIdx),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _editTankDialog(BuildContext context, int initialFuelIdx) async {
    final formKey = GlobalKey<_EditTankDialogContentState>();

    await HighEndDialog.show(
      context: context,
      title: 'แก้ไขถัง',
      icon: Icons.storage_rounded,
      compact: true,
      maxWidth: 400,
      content: _EditTankDialogContent(
        key: formKey,
        tank: tank,
        fuelTypes: fuelTypes,
        initialFuelIdx: initialFuelIdx,
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          expand: false,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(),
        ),
        PrimaryButton(
          label: 'บันทึก',
          expand: false,
          onPressed: () {
            final state = formKey.currentState;
            if (state != null) onChanged(state.buildResult());
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
    );
  }
}

class _EditTankDialogContent extends StatefulWidget {
  final Map<String, dynamic> tank;
  final List<Map<String, dynamic>> fuelTypes;
  final int initialFuelIdx;

  const _EditTankDialogContent({
    super.key,
    required this.tank,
    required this.fuelTypes,
    required this.initialFuelIdx,
  });

  @override
  State<_EditTankDialogContent> createState() => _EditTankDialogContentState();
}

class _EditTankDialogContentState extends State<_EditTankDialogContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _curCtrl;
  late int _fuelIdx;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.tank['name']?.toString() ?? '');
    _capCtrl = TextEditingController(
        text: widget.tank['capacity']?.toString() ?? '10000');
    _curCtrl = TextEditingController(
        text: widget.tank['current_liters']?.toString() ?? '10000');
    _fuelIdx =
        widget.initialFuelIdx.clamp(0, widget.fuelTypes.length - 1);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capCtrl.dispose();
    _curCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> buildResult() {
    final ft = widget.fuelTypes[_fuelIdx];
    final key = ft['id'] != null ? 'id:${ft['id']}' : 'idx:$_fuelIdx';
    return {
      ...widget.tank,
      'name': _nameCtrl.text.trim(),
      'capacity': double.tryParse(_capCtrl.text) ?? 10000,
      'current_liters': double.tryParse(_curCtrl.text) ?? 0,
      'fuel_type_id': ft['id'],
      'fuel_key': key,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompactField(label: 'ชื่อถัง', controller: _nameCtrl),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CompactField(
                label: 'ความจุ (ลิตร)',
                controller: _capCtrl,
                keyboard: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactField(
                label: 'คงเหลือ (ลิตร)',
                controller: _curCtrl,
                keyboard: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _fuelIdx,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'ชนิดน้ำมันในถัง',
            isDense: true,
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          items: List.generate(
            widget.fuelTypes.length,
            (i) => DropdownMenuItem(
              value: i,
              child: Text(widget.fuelTypes[i]['name']?.toString() ?? ''),
            ),
          ),
          onChanged: (v) => setState(() => _fuelIdx = v ?? 0),
        ),
      ],
    );
  }
}

