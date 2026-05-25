import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/license_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';
import 'receipt_designer_screen.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final _repo = SettingsRepository();
  final _station = TextEditingController();
  final _tax = TextEditingController();
  final _address = TextEditingController();
  final _footer = TextEditingController();
  final _lang = TextEditingController(text: 'th-TH');
  bool _ttsEnabled = true;
  bool _loading = true;
  bool _saving = false;
  bool _rechecking = false;

  String _licenseKey = '';
  String _licenseType = 'free';
  bool _licenseVerified = false;
  String _licenseCustomer = '';
  String _licenseExpiry = '';
  String _licenseTokenHint = '';
  bool _hasLicenseToken = false;
  String _licenseGraceMessage = '';
  bool _licenseGraceActive = false;
  bool _licenseGraceExpired = false;
  String _appName = '';
  String _packageName = '';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _station.dispose();
    _tax.dispose();
    _address.dispose();
    _footer.dispose();
    _lang.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settings = await _repo.all();
    final license = await LicenseService.instance.getStoredLicenseInfo();
    final grace = await LicenseService.instance.getGraceStatus();
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;

    final licenseType = license['type'] ?? 'free';
    context.read<AppState>().setLicenseType(licenseType);

    setState(() {
      _station.text = settings['station_name'] ?? '';
      _tax.text = settings['station_tax_id'] ?? '';
      _address.text = settings['station_address'] ?? '';
      _footer.text = settings['receipt_footer'] ?? '';
      _lang.text = settings['tts_language'] ?? 'th-TH';
      _ttsEnabled = (settings['tts_enabled'] ?? 'true') == 'true';
      _licenseKey = license['key'] ?? '';
      _licenseType = license['type'] ?? 'free';
      _licenseVerified = license['verified'] == 'true';
      _licenseCustomer = license['customer_name'] ?? '';
      _licenseExpiry = license['expiry'] ?? '';
      _licenseTokenHint = license['token_hint'] ?? '';
      _hasLicenseToken = license['has_token'] == 'true';
      _licenseGraceActive = grace.active;
      _licenseGraceExpired = grace.expired && _licenseVerified;
      _licenseGraceMessage = grace.displayMessage;
      _appName = pkg.appName;
      _packageName = pkg.packageName;
      _appVersion = '${pkg.version}+${pkg.buildNumber}';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = context.read<AppState>().user?.id;
      await _repo.set('station_name', _station.text.trim());
      await _repo.set('station_tax_id', _tax.text.trim());
      await _repo.set('station_address', _address.text.trim());
      await _repo.set('receipt_footer', _footer.text.trim());
      await _repo.set('tts_language', _lang.text.trim());
      await _repo.set('tts_enabled', _ttsEnabled ? 'true' : 'false');
      await TtsService.instance.reload();
      await DatabaseService.instance.audit(userId, 'settings');
      if (!mounted) return;
      ToastUtils.show(context, 'บันทึกการตั้งค่าแล้ว');
      TtsService.instance.speak('บันทึกการตั้งค่าแล้ว');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recheckLicense() async {
    if (_licenseKey.isEmpty) {
      ToastUtils.show(context, 'ยังไม่มี Product Key');
      return;
    }
    setState(() => _rechecking = true);
    try {
      final result = await LicenseService.instance.refreshStoredLicense();
      if (!mounted) return;
      if (result['success'] == true) {
        final license = await LicenseService.instance.getStoredLicenseInfo();
        final grace = await LicenseService.instance.getGraceStatus();
        if (!mounted) return;
        final type = license['type'] ?? 'free';
        context.read<AppState>().setLicenseType(type);
        setState(() {
          _licenseType = type;
          _licenseVerified = license['verified'] == 'true';
          _licenseCustomer = license['customer_name'] ?? '';
          _licenseExpiry = license['expiry'] ?? '';
          _licenseTokenHint = license['token_hint'] ?? '';
          _hasLicenseToken = license['has_token'] == 'true';
          _licenseGraceActive = grace.active;
          _licenseGraceExpired = false;
          _licenseGraceMessage = grace.displayMessage;
        });
        ToastUtils.show(
          context,
          result['package_from_api'] == true
              ? 'อัปเดต License แล้ว — ${LicenseService.displayLicenseType(type)}'
              : (result['message']?.toString() ??
                  'Server ไม่ส่ง package — ยังเป็น ${LicenseService.displayLicenseType(type)}'),
        );
      } else {
        final grace = await LicenseService.instance.getGraceStatus();
        if (!mounted) return;
        setState(() {
          _licenseGraceActive = grace.active;
          _licenseGraceExpired = grace.expired && _licenseVerified;
          _licenseGraceMessage = grace.displayMessage;
        });
        if (grace.active) {
          ToastUtils.show(
            context,
            '${result['message'] ?? 'เชื่อมต่อไม่ได้'} — ${grace.displayMessage}',
          );
        } else {
          ToastUtils.show(
            context,
            result['message']?.toString() ?? 'ตรวจสอบ License ไม่สำเร็จ',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _rechecking = false);
    }
  }

  Future<void> _copyProductKey() async {
    if (_licenseKey.isEmpty) {
      ToastUtils.show(context, 'ยังไม่มี Product Key');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _licenseKey));
    if (!mounted) return;
    ToastUtils.show(context, 'คัดลอก Product Key แล้ว');
  }

  String get _packageLabel =>
      LicenseService.displayLicenseType(_licenseType);

  Color get _packageColor {
    switch (_licenseType.toLowerCase()) {
      case 'pro':
        return AppColors.success;
      case 'standard':
        return AppColors.corporateBlue;
      case 'enterprise':
        return AppColors.success;
      case 'free':
        return AppColors.greyMedium;
      default:
        return AppColors.corporateBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pad = r.w(12);
    final wide = r.width >= 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'ตั้งค่าทั่วไป',
        subtitle: 'ข้อมูลสถานี · ใบเสร็จ · License',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.w(4)),
            child: _saving
                ? Padding(
                    padding: EdgeInsets.all(r.w(12)),
                    child: SizedBox(
                      width: r.sp(18),
                      height: r.sp(18),
                      child: const CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: Icon(Icons.save_rounded,
                        color: AppColors.white, size: r.sp(18)),
                    label: Text(
                      'บันทึก',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: r.sp(11),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          AppColors.white.withValues(alpha: 0.15),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.w(12), vertical: r.h(6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.r(8)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  _licenseSection(r),
                  SizedBox(height: pad),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _stationSection(r)),
                        SizedBox(width: pad),
                        Expanded(child: _ttsSection(r)),
                      ],
                    )
                  else ...[
                    _stationSection(r),
                    SizedBox(height: pad),
                    _ttsSection(r),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _licenseSection(Responsive r) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  color: AppColors.corporateBlue, size: r.sp(18)),
              SizedBox(width: r.w(8)),
              Text(
                'License & Package',
                style: TextStyle(
                  fontSize: r.sp(12),
                  fontWeight: FontWeight.w900,
                  color: AppColors.corporateBlueDark,
                ),
              ),
              const Spacer(),
              _PackageBadge(
                r: r,
                label: _packageLabel,
                color: _packageColor,
                verified: _licenseVerified,
              ),
            ],
          ),
          SizedBox(height: r.h(10)),
          _InfoTile(
            r: r,
            icon: Icons.vpn_key_rounded,
            label: 'Product Key',
            value: _licenseKey.isEmpty ? 'ยังไม่ได้ลงทะเบียน' : _licenseKey,
            monospace: _licenseKey.isNotEmpty,
            trailing: _licenseKey.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.copy_rounded,
                        size: r.sp(18), color: AppColors.corporateBlue),
                    tooltip: 'คัดลอก',
                    onPressed: _copyProductKey,
                  )
                : null,
          ),
          SizedBox(height: r.h(8)),
          _InfoTile(
            r: r,
            icon: Icons.inventory_2_outlined,
            label: 'Package',
            value: _packageLabel,
          ),
          SizedBox(height: r.h(8)),
          _InfoTile(
            r: r,
            icon: Icons.cloud_circle_outlined,
            label: 'Cloud token',
            value: _hasLicenseToken
                ? '${_licenseTokenHint} (พร้อมสำรองคลาวด์)'
                : 'ยังไม่มี — กดตรวจสอบ License ใหม่',
          ),
          if (_licenseCustomer.isNotEmpty) ...[
            SizedBox(height: r.h(8)),
            _InfoTile(
              r: r,
              icon: Icons.store_rounded,
              label: 'ลูกค้า',
              value: _licenseCustomer,
            ),
          ],
          if (_licenseExpiry.isNotEmpty) ...[
            SizedBox(height: r.h(8)),
            _InfoTile(
              r: r,
              icon: Icons.event_rounded,
              label: 'หมดอายุ',
              value: _licenseExpiry,
            ),
          ],
          if (_licenseVerified &&
              (_licenseGraceActive || _licenseGraceExpired) &&
              _licenseGraceMessage.isNotEmpty) ...[
            SizedBox(height: r.h(8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.w(10)),
              decoration: BoxDecoration(
                color: (_licenseGraceExpired ? AppColors.gold : AppColors.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.r(8)),
                border: Border.all(
                  color: (_licenseGraceExpired ? AppColors.gold : AppColors.success)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _licenseGraceExpired
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_off_rounded,
                    size: r.sp(16),
                    color: _licenseGraceExpired ? AppColors.gold : AppColors.success,
                  ),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: Text(
                      _licenseGraceMessage,
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
          SizedBox(height: r.h(8)),
          _InfoTile(
            r: r,
            icon: Icons.apps_rounded,
            label: 'แอป',
            value: '$_appName · v$_appVersion',
          ),
          SizedBox(height: r.h(4)),
          Padding(
            padding: EdgeInsets.only(left: r.w(28)),
            child: Text(
              _packageName,
              style: TextStyle(
                fontSize: r.sp(9),
                color: AppColors.greyMedium,
              ),
            ),
          ),
          SizedBox(height: r.h(10)),
          Material(
            color: AppColors.corporateBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.r(10)),
            child: InkWell(
              borderRadius: BorderRadius.circular(r.r(10)),
              onTap: _rechecking || _licenseKey.isEmpty
                  ? null
                  : _recheckLicense,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(12), vertical: r.h(10)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.r(10)),
                  border: Border.all(
                    color: AppColors.corporateBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_rechecking)
                      SizedBox(
                        width: r.sp(16),
                        height: r.sp(16),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.corporateBlue,
                        ),
                      )
                    else
                      Icon(Icons.sync_rounded,
                          color: AppColors.corporateBlue, size: r.sp(16)),
                    SizedBox(width: r.w(8)),
                    Text(
                      _rechecking
                          ? 'กำลังตรวจสอบ…'
                          : 'ตรวจสอบ License ใหม่',
                      style: TextStyle(
                        fontSize: r.sp(11),
                        fontWeight: FontWeight.w800,
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_licenseKey.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: r.h(6), left: r.w(4)),
              child: Text(
                'ใช้เมื่อ Package เปลี่ยนบนเซิร์ฟเวอร์ — อัปเดตสิทธิ์ module ทันที',
                style: TextStyle(
                  fontSize: r.sp(9),
                  color: AppColors.greyMedium,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stationSection(Responsive r) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ข้อมูลสถานี',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: r.sp(12),
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(4)),
          Text(
            'แสดงบนใบเสร็จและรายงาน',
            style: TextStyle(fontSize: r.sp(9), color: AppColors.greyMedium),
          ),
          SizedBox(height: r.h(10)),
          _field(
            r: r,
            controller: _station,
            label: 'ชื่อปั๊ม / สถานี',
            icon: Icons.local_gas_station_rounded,
          ),
          SizedBox(height: r.h(8)),
          _field(
            r: r,
            controller: _tax,
            label: 'เลขประจำตัวผู้เสียภาษี',
            icon: Icons.numbers_rounded,
          ),
          SizedBox(height: r.h(8)),
          _field(
            r: r,
            controller: _address,
            label: 'ที่อยู่',
            icon: Icons.location_on_outlined,
            maxLines: 3,
          ),
          SizedBox(height: r.h(8)),
          _field(
            r: r,
            controller: _footer,
            label: 'ข้อความท้ายใบเสร็จ (ค่าเริ่มต้น)',
            icon: Icons.notes_rounded,
            maxLines: 2,
            helper: 'ใช้ใน {receipt_footer} บน designer',
          ),
          SizedBox(height: r.h(10)),
          PrimaryButton(
            label: 'ออกแบบหัว/ท้ายใบเสร็จ',
            icon: Icons.design_services_rounded,
            variant: ButtonVariant.outline,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReceiptDesignerScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ttsSection(Responsive r) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'เสียงพูด (TTS)',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: r.sp(12),
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(4)),
          Text(
            'แจ้งเตือนด้วยเสียงเมื่อทำรายการ',
            style: TextStyle(fontSize: r.sp(9), color: AppColors.greyMedium),
          ),
          SizedBox(height: r.h(8)),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.w(10), vertical: r.h(4)),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(r.r(10)),
              border: Border.all(color: AppColors.greyLight),
            ),
            child: Row(
              children: [
                Icon(Icons.volume_up_rounded,
                    color: AppColors.corporateBlue, size: r.sp(18)),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Text(
                    'เปิดเสียงแจ้งเตือน',
                    style: TextStyle(
                      fontSize: r.sp(11),
                      fontWeight: FontWeight.w700,
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                ),
                Switch(
                  value: _ttsEnabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => _ttsEnabled = v),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(8)),
          _field(
            r: r,
            controller: _lang,
            label: 'รหัสภาษา',
            icon: Icons.translate_rounded,
            hint: 'th-TH, en-US',
          ),
          SizedBox(height: r.h(10)),
          PrimaryButton(
            label: 'ทดสอบเสียง',
            icon: Icons.play_arrow_rounded,
            variant: ButtonVariant.outline,
            onPressed: () => TtsService.instance.speak('ระบบพร้อมใช้งาน'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required Responsive r,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? hint,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: r.sp(12)),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperStyle: TextStyle(fontSize: r.sp(9)),
        labelStyle: TextStyle(fontSize: r.sp(10)),
        prefixIcon: Icon(icon, size: r.sp(18)),
        filled: true,
        fillColor: AppColors.softWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.r(10)),
          borderSide: const BorderSide(color: AppColors.greyLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.r(10)),
          borderSide: const BorderSide(color: AppColors.greyLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.r(10)),
          borderSide: const BorderSide(
            color: AppColors.corporateBlue,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _PackageBadge extends StatelessWidget {
  final Responsive r;
  final String label;
  final Color color;
  final bool verified;

  const _PackageBadge({
    required this.r,
    required this.label,
    required this.color,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(4)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r.r(20)),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: r.sp(12),
            color: color,
          ),
          SizedBox(width: r.w(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(10),
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final Responsive r;
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;
  final Widget? trailing;

  const _InfoTile({
    required this.r,
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(8)),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(r.r(10)),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: r.sp(16), color: AppColors.corporateBlue),
          SizedBox(width: r.w(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: r.sp(9),
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyMedium,
                  ),
                ),
                SizedBox(height: r.h(2)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w700,
                    color: value.contains('ยังไม่')
                        ? AppColors.greyMedium
                        : AppColors.corporateBlueDark,
                    fontFamily: monospace ? 'monospace' : null,
                    letterSpacing: monospace ? 0.8 : null,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
