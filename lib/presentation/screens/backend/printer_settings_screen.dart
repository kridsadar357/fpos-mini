import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/bluetooth_printer_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';
import 'receipt_designer_screen.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _svc = BluetoothPrinterService.instance;
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;
  bool _connected = false;
  bool _bluetoothGranted = true;
  PaperSize _paperSize = PaperSize.mm80;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _svc.loadPaperSize();
    if (!mounted) return;
    setState(() => _paperSize = _svc.paperSize);

    final granted = await _svc.ensurePermissions();
    if (!mounted) return;
    setState(() => _bluetoothGranted = granted);
    if (!granted) return;

    await _scan();
    if (_devices.isNotEmpty && !_connected) {
      await _svc.connectLastUsed();
      if (mounted) await _scan();
    }
  }

  Future<void> _requestBluetoothPermission() async {
    final granted = await _svc.ensurePermissions();
    if (!mounted) return;
    setState(() => _bluetoothGranted = granted);
    if (granted) {
      await _scan();
      ToastUtils.show(context, 'อนุญาต Bluetooth แล้ว');
    } else {
      ToastUtils.show(
        context,
        'กรุณาอนุญาต Nearby devices ใน Settings ของแอป',
      );
    }
  }

  Future<void> _scan() async {
    if (!await _svc.ensurePermissions(request: false)) {
      if (mounted) setState(() => _bluetoothGranted = false);
      return;
    }
    setState(() => _scanning = true);
    final devices = await _svc.listBondedDevices();
    final connected = await _svc.isConnected;
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _connected = connected;
      _scanning = false;
    });
  }

  Future<void> _connect(BluetoothDevice d) async {
    ToastUtils.show(context, 'กำลังเชื่อมต่อ ${d.name ?? d.address}...');
    final ok = await _svc.connectTo(d);
    if (!mounted) return;
    setState(() => _connected = ok);
    ToastUtils.show(
      context,
      ok ? 'เชื่อมต่อเครื่องพิมพ์แล้ว' : 'เชื่อมต่อไม่สำเร็จ',
    );
  }

  Future<void> _disconnect() async {
    await _svc.disconnect();
    if (!mounted) return;
    setState(() => _connected = false);
    ToastUtils.show(context, 'ตัดการเชื่อมต่อแล้ว');
  }

  Future<void> _setPaper(PaperSize size) async {
    await _svc.savePaperSize(size);
    if (!mounted) return;
    setState(() => _paperSize = size);
    ToastUtils.show(
      context,
      'ตั้งค่ากระดาษ ${size == PaperSize.mm58 ? '58' : '80'} mm แล้ว',
    );
  }

  Future<void> _test() async {
    if (!_connected) {
      final ok = await _svc.connectLastUsed();
      if (!ok) {
        if (!mounted) return;
        ToastUtils.show(context, 'ยังไม่ได้เชื่อมต่อเครื่องพิมพ์');
        return;
      }
      setState(() => _connected = true);
    }
    final ok = await _svc.printTestPageWithInfo();
    if (!mounted) return;
    ToastUtils.show(
      context,
      ok ? 'ส่งหน้าทดสอบแล้ว (${_svc.paperSizeLabel})' : 'พิมพ์ไม่สำเร็จ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final current = _svc.device;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'เครื่องพิมพ์',
        subtitle: 'Bluetooth ESC/POS • ${_svc.paperSizeLabel}',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppColors.white, size: r.sp(22)),
            onPressed: _scanning ? null : _scan,
            tooltip: 'สแกนใหม่',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          padding: EdgeInsets.all(r.w(10)),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _StatusBar(
              r: r,
              connected: _connected,
              paperLabel: _svc.paperSizeLabel,
              deviceCount: _devices.length,
            ),
            SizedBox(height: r.h(10)),
            if (!_bluetoothGranted) ...[
              _PermissionCard(
                r: r,
                onAllow: _requestBluetoothPermission,
                onOpenSettings: () => _svc.openPermissionSettings(),
              ),
              SizedBox(height: r.h(10)),
            ],
            if (current != null)
              _ConnectedCard(
                r: r,
                name: current.name ?? 'เครื่องพิมพ์',
                address: current.address,
                connected: _connected,
                onDisconnect: _connected ? _disconnect : null,
              ),
            if (current != null) SizedBox(height: r.h(10)),
            GlassCard(
              padding: EdgeInsets.all(r.w(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ขนาดกระดาษ',
                    style: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w900,
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                  SizedBox(height: r.h(4)),
                  Text(
                    '80 mm มาตรฐานเคาน์เตอร์ • 58 mm สำหรับพกพา',
                    style: TextStyle(
                      color: AppColors.greyMedium,
                      fontSize: r.sp(9),
                    ),
                  ),
                  SizedBox(height: r.h(8)),
                  SegmentedButton<PaperSize>(
                    segments: const [
                      ButtonSegment(
                        value: PaperSize.mm58,
                        label: Text('58 mm'),
                        icon: Icon(Icons.receipt_long_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: PaperSize.mm80,
                        label: Text('80 mm'),
                        icon: Icon(Icons.receipt_rounded, size: 16),
                      ),
                    ],
                    selected: {_paperSize},
                    onSelectionChanged: (s) => _setPaper(s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: r.sp(10),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.h(10)),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'ทดสอบพิมพ์',
                    icon: Icons.print_rounded,
                    onPressed: _test,
                  ),
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: PrimaryButton(
                    label: 'ออกแบบใบเสร็จ',
                    icon: Icons.design_services_rounded,
                    variant: ButtonVariant.outline,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReceiptDesignerScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.h(12)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'เครื่องพิมพ์ที่จับคู่แล้ว',
                    style: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w900,
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                ),
                if (_scanning)
                  SizedBox(
                    width: r.sp(16),
                    height: r.sp(16),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: r.h(6)),
            _SetupSteps(r: r),
            SizedBox(height: r.h(8)),
            if (!_scanning && _devices.isEmpty)
              GlassCard(
                padding: EdgeInsets.all(r.w(20)),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_searching_rounded,
                      size: r.sp(40),
                      color: AppColors.greyLight,
                    ),
                    SizedBox(height: r.h(8)),
                    Text(
                      'ไม่พบเครื่องพิมพ์',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: r.sp(12),
                        color: AppColors.greyDark,
                      ),
                    ),
                    SizedBox(height: r.h(4)),
                    Text(
                      'จับคู่ใน Bluetooth ของระบบ\nแล้วกดรีเฟรชมุมขวาบน',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.greyMedium,
                        fontSize: r.sp(10),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._devices.map(
                (d) => Padding(
                  padding: EdgeInsets.only(bottom: r.h(6)),
                  child: _DeviceTile(
                    r: r,
                    device: d,
                    isActive: current?.address == d.address,
                    connected: _connected && current?.address == d.address,
                    onTap: () => _connect(d),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final Responsive r;
  final bool connected;
  final String paperLabel;
  final int deviceCount;

  const _StatusBar({
    required this.r,
    required this.connected,
    required this.paperLabel,
    required this.deviceCount,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatusItem(
        connected ? 'สถานะ' : 'สถานะ',
        connected ? 'เชื่อมต่อแล้ว' : 'ยังไม่เชื่อมต่อ',
        connected ? AppColors.success : AppColors.danger,
      ),
      _StatusItem('กระดาษ', paperLabel, AppColors.corporateBlue),
      _StatusItem('พบเครื่อง', '$deviceCount', AppColors.fuelBenzene),
    ];

    return Row(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < items.length - 1 ? r.w(6) : 0),
            padding: EdgeInsets.symmetric(
              horizontal: r.w(8),
              vertical: r.h(8),
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.greyLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sp(8),
                    color: AppColors.greyMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w900,
                    color: e.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusItem {
  final String label;
  final String value;
  final Color color;

  const _StatusItem(this.label, this.value, this.color);
}

class _PermissionCard extends StatelessWidget {
  final Responsive r;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  const _PermissionCard({
    required this.r,
    required this.onAllow,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth_disabled_rounded,
                  color: AppColors.danger, size: r.sp(20)),
              SizedBox(width: r.w(8)),
              Expanded(
                child: Text(
                  'ยังไม่ได้อนุญาต Bluetooth',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: r.sp(11),
                    color: AppColors.corporateBlueDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(8)),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'อนุญาต',
                  expand: false,
                  onPressed: onAllow,
                ),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                child: PrimaryButton(
                  label: 'Settings',
                  variant: ButtonVariant.outline,
                  expand: false,
                  onPressed: onOpenSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final Responsive r;
  final String name;
  final String address;
  final bool connected;
  final VoidCallback? onDisconnect;

  const _ConnectedCard({
    required this.r,
    required this.name,
    required this.address,
    required this.connected,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : AppColors.danger;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(r.w(12)),
        child: Row(
          children: [
            Container(
              width: r.w(40),
              height: r.w(40),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.print_rounded, color: color, size: r.sp(22)),
            ),
            SizedBox(width: r.w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: r.sp(12),
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                  Text(
                    address,
                    style: TextStyle(
                      color: AppColors.greyMedium,
                      fontSize: r.sp(9),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: r.h(4)),
                    padding: EdgeInsets.symmetric(
                      horizontal: r.w(6),
                      vertical: r.h(1),
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      connected ? 'เชื่อมต่อแล้ว' : 'ไม่ได้เชื่อมต่อ',
                      style: TextStyle(
                        fontSize: r.sp(8),
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onDisconnect != null)
              TextButton(
                onPressed: onDisconnect,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'ตัด',
                  style: TextStyle(
                    fontSize: r.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetupSteps extends StatelessWidget {
  final Responsive r;

  const _SetupSteps({required this.r});

  static const _steps = [
    'อนุญาต Bluetooth ของแอป',
    'จับคู่เครื่องพิมพ์ใน Settings ระบบ',
    'กดรีเฟรชมุมขวาบน',
    'แตะชื่อเครื่องเพื่อเชื่อมต่อ',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(10)),
      child: Column(
        children: List.generate(_steps.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? r.h(6) : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: r.w(20),
                  height: r.w(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.corporateBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: r.sp(9),
                      fontWeight: FontWeight.w900,
                      color: AppColors.corporateBlue,
                    ),
                  ),
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Text(
                    _steps[i],
                    style: TextStyle(
                      fontSize: r.sp(10),
                      color: AppColors.greyDark,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final Responsive r;
  final BluetoothDevice device;
  final bool isActive;
  final bool connected;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.r,
    required this.device,
    required this.isActive,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        connected && isActive ? AppColors.success : AppColors.corporateBlue;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive && connected
                  ? AppColors.success.withValues(alpha: 0.5)
                  : AppColors.greyLight,
              width: isActive && connected ? 2 : 1,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: r.w(10),
            vertical: r.h(10),
          ),
          child: Row(
            children: [
              Container(
                width: r.w(36),
                height: r.w(36),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bluetooth_rounded,
                  color: accent,
                  size: r.sp(20),
                ),
              ),
              SizedBox(width: r.w(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? 'ไม่ทราบชื่อ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: r.sp(11),
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                    Text(
                      device.address,
                      style: TextStyle(
                        fontSize: r.sp(9),
                        color: AppColors.greyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                connected && isActive
                    ? Icons.check_circle_rounded
                    : Icons.link_rounded,
                color: accent,
                size: r.sp(20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
