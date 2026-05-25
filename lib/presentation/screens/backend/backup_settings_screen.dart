import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/license_features.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';
import '../splash_screen.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _repo = SettingsRepository();
  final _endpoint = TextEditingController();
  final _token = TextEditingController();
  bool _cloudEnabled = false;
  bool _autoLocalEnabled = true;
  bool _busy = false;
  String _lastBackup = '-';
  String _cloudStatus = '-';
  String _cloudError = '';
  BackupHealthStatus? _backupHealth;
  List<LocalBackupInfo> _localBackups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _repo.all();
    final backups = await BackupService.instance.listLocalBackups();
    final health = await BackupService.instance.evaluateBackupHealth();
    if (!mounted) return;
    setState(() {
      _cloudEnabled = (all['backup_cloud_enabled'] ?? 'false') == 'true';
      _autoLocalEnabled =
          (all['auto_local_backup_enabled'] ?? 'true') == 'true';
      _endpoint.text = all['backup_cloud_endpoint'] ?? '';
      _token.text = all['backup_cloud_token'] ?? '';
      _lastBackup = all['last_local_backup_at'] ?? '-';
      _cloudStatus = all['last_cloud_backup_status'] ?? '-';
      _cloudError = all['last_cloud_backup_error'] ?? '';
      _backupHealth = health;
      _localBackups = backups;
    });
  }

  Future<void> _save({bool silent = false}) async {
    final canCloud = mounted &&
        context.read<AppState>().canUse(AppFeature.cloudBackup);
    await _repo.set(
        'backup_cloud_enabled',
        canCloud && _cloudEnabled ? 'true' : 'false');
    await _repo.set('auto_local_backup_enabled',
        _autoLocalEnabled ? 'true' : 'false');
    await _repo.set('backup_cloud_endpoint', _endpoint.text.trim());
    await _repo.set('backup_cloud_token', _token.text.trim());
    if (!mounted) return;
    if (!silent) ToastUtils.show(context, 'บันทึกการตั้งค่าแล้ว');
  }

  String get _lastBackupLabel {
    if (_lastBackup == '-') return '-';
    final dt = DateTime.tryParse(_lastBackup);
    return dt != null ? Fmt.dateTime(dt) : _lastBackup;
  }

  Future<void> _saveLocal() async {
    if (kIsWeb) {
      _showWebNotice();
      return;
    }
    setState(() => _busy = true);
    try {
      final info = await BackupService.instance.saveToLocalStorage();
      if (!mounted) return;
      if (info != null) {
        final userId = context.read<AppState>().user?.id;
        await DatabaseService.instance.audit(userId, 'backup',
            details: info.name);
        ToastUtils.show(context, 'บันทึกสำรองในเครื่องแล้ว');
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportLocal() async {
    if (kIsWeb) {
      _showWebNotice();
      return;
    }
    setState(() => _busy = true);
    try {
      await BackupService.instance.shareLocalBackup();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToPath({String? existingPath}) async {
    if (kIsWeb) {
      _showWebNotice();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await BackupService.instance.saveBackupToUserPath(
        existingPath: existingPath,
      );
      if (!mounted) return;
      if (result.ok) {
        ToastUtils.show(context, result.message);
      } else if (result.message != 'ยกเลิกการบันทึก') {
        ToastUtils.show(context, result.message);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadCloud() async {
    setState(() => _busy = true);
    final result = await BackupService.instance.uploadToCloud();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok ? AppColors.success : AppColors.danger,
      ),
    );
    _load();
  }

  Future<void> _shareExisting(LocalBackupInfo info) async {
    if (kIsWeb) {
      _showWebNotice();
      return;
    }
    setState(() => _busy = true);
    try {
      await Share.shareXFiles(
        [XFile(info.path)],
        text: 'FUEL POS Backup',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromInfo(LocalBackupInfo info) async {
    final confirmed = await HighEndDialog.show<bool>(
      context: context,
      title: 'กู้คืนฐานข้อมูล',
      message:
          'ไฟล์ "${info.name}" จะแทนที่ข้อมูลปัจจุบัน\n(ระบบจะสำรองก่อนกู้คืนอัตโนมัติ)',
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.danger,
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          expand: false,
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'กู้คืน',
          expand: false,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final userId = context.read<AppState>().user?.id;
    setState(() => _busy = true);
    final result =
        await BackupService.instance.restoreFromPath(info.path);
    if (result.ok) {
      await DatabaseService.instance.audit(userId, 'restore',
          details: info.name);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } else {
      ToastUtils.show(context, result.message);
    }
  }

  Future<void> _restore() async {
    if (kIsWeb) {
      _showWebNotice();
      return;
    }
    final confirmed = await HighEndDialog.show<bool>(
      context: context,
      title: 'กู้คืนฐานข้อมูล',
      message:
          'ไฟล์ที่เลือกจะแทนที่ข้อมูลปัจจุบันทั้งหมด\n(ระบบจะสำรองก่อนกู้คืนอัตโนมัติ)',
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.danger,
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          expand: false,
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'กู้คืน',
          expand: false,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final userId = context.read<AppState>().user?.id;
    setState(() => _busy = true);
    final result = await BackupService.instance.restoreFromFile();
    if (result.ok) {
      await DatabaseService.instance.audit(userId, 'restore');
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (_) => false,
      );
    } else {
      ToastUtils.show(context, result.message);
    }
  }

  Future<void> _exportCsv() async {
    if (kIsWeb) {
      _showWebNotice();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await BackupService.instance.saveCsvToUserPath();
      if (!mounted) return;
      if (result.ok) {
        ToastUtils.show(context, result.message);
      } else if (result.message != 'ยกเลิกการบันทึก') {
        ToastUtils.show(context, result.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showWebNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'ฟีเจอร์นี้ใช้ได้บนแอปมือถือ/แท็บเล็ต — ไม่รองรับเวอร์ชันเว็บ'),
        backgroundColor: AppColors.corporateBlueDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pad = r.w(12);
    final wide = r.width >= 720;
    final canCloud =
        context.watch<AppState>().canUse(AppFeature.cloudBackup);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'สำรองข้อมูล',
        subtitle: 'สำรองและกู้คืนข้อมูล',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final files = _backupFilesSection(r);

            if (wide) {
              return Padding(
                padding: EdgeInsets.all(pad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _localSection(r)),
                    SizedBox(width: pad),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (canCloud) _cloudSection(r),
                          if (canCloud && files != null) ...[
                            SizedBox(height: pad),
                            Expanded(child: files),
                          ] else if (!canCloud && files != null) ...[
                            Expanded(child: files),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.all(pad),
              children: [
                _localSection(r, withFiles: true),
                if (canCloud) ...[
                  SizedBox(height: pad),
                  _cloudSection(r),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _localSection(Responsive r, {bool withFiles = false}) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'สำรองในเครื่อง',
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontWeight: FontWeight.w900,
                    fontSize: r.sp(14),
                  ),
                ),
              ),
              Text(
                'อัตโนมัติ',
                style: TextStyle(
                  fontSize: r.sp(10),
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyMedium,
                ),
              ),
              SizedBox(width: r.w(4)),
              Switch(
                value: _autoLocalEnabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) async {
                  setState(() => _autoLocalEnabled = v);
                  await _save(silent: true);
                },
              ),
            ],
          ),
          Text(
            'schema เปลี่ยน / ทุก 24 ชม. · ล่าสุด $_lastBackupLabel',
            style: TextStyle(
              fontSize: r.sp(10),
              color: AppColors.greyMedium,
              height: 1.3,
            ),
          ),
          if (_backupHealth?.isStale == true &&
              _backupHealth?.message != null) ...[
            SizedBox(height: r.h(6)),
            Container(
              padding: EdgeInsets.all(r.w(8)),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.r(8)),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger, size: r.sp(16)),
                  SizedBox(width: r.w(6)),
                  Expanded(
                    child: Text(
                      _backupHealth!.message!,
                      style: TextStyle(
                        fontSize: r.sp(10),
                        color: AppColors.danger,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: r.h(4)),
          Text(
            '「แชร์」ส่งให้แอปอื่น · 「บันทึกไปที่…」เลือกโฟลเดอร์ในเครื่อง (Downloads ฯลฯ)',
            style: TextStyle(
              fontSize: r.sp(9),
              color: AppColors.greyMedium,
              height: 1.3,
            ),
          ),
          SizedBox(height: r.h(8)),
          _actionGrid(r),
          if (withFiles && _localBackups.isNotEmpty) ...[
            SizedBox(height: r.h(10)),
            const Divider(height: 1, color: AppColors.greyLight),
            SizedBox(height: r.h(8)),
            Text(
              'ไฟล์สำรอง (${_localBackups.length})',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: r.sp(11),
                color: AppColors.corporateBlueDark,
              ),
            ),
            SizedBox(height: r.h(6)),
            ..._localBackups.map((b) => _backupTile(r, b)),
          ],
        ],
      ),
    );
  }

  Widget _actionGrid(Responsive r) {
    Widget row(List<Widget> buttons) => Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) SizedBox(width: r.w(8)),
              Expanded(child: buttons[i]),
            ],
          ],
        );

    return Column(
      children: [
        row([
          _compactBtn(
            r: r,
            label: 'บันทึกสำรอง',
            icon: Icons.save_rounded,
            primary: true,
            loading: _busy,
            onPressed: _saveLocal,
          ),
          _compactBtn(
            r: r,
            label: 'บันทึกไปที่…',
            icon: Icons.drive_file_move_rounded,
            loading: _busy,
            onPressed: () => _saveToPath(),
          ),
        ]),
        SizedBox(height: r.h(6)),
        row([
          _compactBtn(
            r: r,
            label: 'แชร์',
            icon: Icons.ios_share_rounded,
            loading: _busy,
            onPressed: _exportLocal,
          ),
          _compactBtn(
            r: r,
            label: 'กู้คืนไฟล์',
            icon: Icons.restore_rounded,
            loading: _busy,
            onPressed: _restore,
          ),
        ]),
        SizedBox(height: r.h(6)),
        row([
          _compactBtn(
            r: r,
            label: 'ส่งออก CSV',
            icon: Icons.table_chart_rounded,
            loading: _busy,
            onPressed: _exportCsv,
          ),
          const SizedBox(),
        ]),
      ],
    );
  }

  Widget _cloudSection(Responsive r) {
    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(4)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: r.w(4)),
          childrenPadding: EdgeInsets.fromLTRB(r.w(4), 0, r.w(4), r.h(8)),
          initiallyExpanded: _cloudEnabled,
          leading: Icon(
            Icons.cloud_outlined,
            color: AppColors.corporateBlue,
            size: r.sp(20),
          ),
          title: Text(
            'สำรองคลาวด์ (ไม่บังคับ)',
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontWeight: FontWeight.w800,
              fontSize: r.sp(13),
            ),
          ),
          subtitle: Text(
            _cloudEnabled
                ? (_cloudStatus == 'ok'
                    ? 'อัปโหลดล่าสุดสำเร็จ'
                    : _cloudError.isNotEmpty
                        ? 'ล้มเหลว: $_cloudError'
                        : 'เปิดใช้งาน')
                : 'ปิดอยู่',
            style: TextStyle(fontSize: r.sp(10), color: AppColors.greyMedium),
          ),
          children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              value: _cloudEnabled,
              title: Text('เปิดใช้สำรองคลาวด์', style: TextStyle(fontSize: r.sp(12))),
              onChanged: (v) => setState(() => _cloudEnabled = v),
            ),
            TextField(
              controller: _endpoint,
              style: TextStyle(fontSize: r.sp(12)),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'URL (HTTPS)',
                hintText: 'https://your-server/backup',
                labelStyle: TextStyle(fontSize: r.sp(11)),
              ),
            ),
            SizedBox(height: r.h(6)),
            TextField(
              controller: _token,
              obscureText: true,
              style: TextStyle(fontSize: r.sp(12)),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Token (ไม่บังคับ)',
                labelStyle: TextStyle(fontSize: r.sp(11)),
              ),
            ),
            SizedBox(height: r.h(8)),
            Row(
              children: [
                Expanded(
                  child: _compactBtn(
                    r: r,
                    label: 'อัปโหลด',
                    icon: Icons.cloud_upload_rounded,
                    primary: true,
                    loading: _busy,
                    onPressed: _cloudEnabled ? _uploadCloud : null,
                  ),
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: _compactBtn(
                    r: r,
                    label: 'บันทึกตั้งค่า',
                    icon: Icons.settings_rounded,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _backupFilesSection(Responsive r) {
    if (_localBackups.isEmpty) return null;

    return GlassCard(
      padding: EdgeInsets.all(r.w(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ไฟล์สำรอง (${_localBackups.length})',
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontWeight: FontWeight.w900,
              fontSize: r.sp(12),
            ),
          ),
          SizedBox(height: r.h(8)),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _localBackups.length,
              itemBuilder: (_, i) => _backupTile(r, _localBackups[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupTile(Responsive r, LocalBackupInfo b) {
    return Container(
      margin: EdgeInsets.only(bottom: r.h(4)),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(r.r(8)),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(horizontal: r.w(8)),
        leading: Icon(Icons.storage_rounded,
            color: AppColors.corporateBlue, size: r.sp(18)),
        title: Text(
          b.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.sp(10),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${b.sizeLabel} · ${Fmt.dateTime(b.modifiedAt)}',
          style: TextStyle(fontSize: r.sp(9)),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              size: r.sp(20), color: AppColors.corporateBlue),
          enabled: !_busy,
          onSelected: (v) {
            switch (v) {
              case 'restore':
                _restoreFromInfo(b);
              case 'save':
                _saveToPath(existingPath: b.path);
              case 'share':
                _shareExisting(b);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'restore', child: Text('กู้คืน')),
            PopupMenuItem(value: 'save', child: Text('บันทึกไปที่…')),
            PopupMenuItem(value: 'share', child: Text('แชร์')),
          ],
        ),
      ),
    );
  }

  Widget _compactBtn({
    required Responsive r,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool primary = false,
    bool loading = false,
  }) {
    final bg = primary ? AppColors.red : AppColors.white;
    final fg = primary ? AppColors.white : AppColors.corporateBlueDark;
    final border = primary
        ? null
        : Border.all(color: AppColors.corporateBlue, width: 1.5);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(r.r(10)),
      elevation: primary ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(r.r(10)),
        onTap: loading ? null : onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: r.h(38)),
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(r.r(10)),
          ),
          padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(8)),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: r.sp(14),
                  height: r.sp(14),
                  child: CircularProgressIndicator(
                    color: fg,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                Icon(icon, color: fg, size: r.sp(16)),
                SizedBox(width: r.w(4)),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
