import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/audit_log_entry.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _repo = AuditLogRepository();

  static const _filters = <({String? action, String label})>[
    (action: null, label: 'ทั้งหมด'),
    (action: 'login', label: 'เข้าสู่ระบบ'),
    (action: 'logout', label: 'ออกจากระบบ'),
    (action: 'shift_open', label: 'เปิดกะ'),
    (action: 'shift_close', label: 'ปิดกะ'),
    (action: 'sale', label: 'ขาย'),
    (action: 'product_sale', label: 'ขายสินค้า'),
    (action: 'print', label: 'พิมพ์'),
    (action: 'backup', label: 'สำรอง'),
    (action: 'restore', label: 'กู้คืน'),
    (action: 'settings', label: 'ตั้งค่า'),
  ];

  List<AuditLogEntry> _logs = [];
  Map<String, int> _todayCounts = {};
  String? _filter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _repo.listRecent(action: _filter);
    final counts = await _repo.countByActionToday();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _todayCounts = counts;
      _loading = false;
    });
  }

  int get _todayTotal =>
      _todayCounts.values.fold<int>(0, (sum, n) => sum + n);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pad = r.w(12);
    final wide = r.width >= 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'บันทึกกิจกรรม',
        subtitle: _loading
            ? 'กำลังโหลด…'
            : 'วันนี้ $_todayTotal รายการ · แสดง ${_logs.length} รายการ',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppColors.white, size: r.sp(22)),
            tooltip: 'รีเฟรช',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: wide ? _wideBody(r, pad) : _narrowBody(r, pad),
              ),
      ),
    );
  }

  Widget _wideBody(Responsive r, double pad) {
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.w(240),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _statsSection(r),
                SizedBox(height: pad),
                _filterSection(r),
              ],
            ),
          ),
          SizedBox(width: pad),
          Expanded(child: _logList(r, pad)),
        ],
      ),
    );
  }

  Widget _narrowBody(Responsive r, double pad) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(pad),
      children: [
        _statsSection(r),
        SizedBox(height: pad),
        _filterSection(r),
        SizedBox(height: pad),
        _logList(r, pad, embedded: true),
      ],
    );
  }

  Widget _statsSection(Responsive r) {
    if (_todayCounts.isEmpty) {
      return GlassCard(
        padding: EdgeInsets.all(r.w(12)),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded,
                color: AppColors.greyMedium, size: r.sp(22)),
            SizedBox(width: r.w(10)),
            Expanded(
              child: Text(
                'ยังไม่มีกิจกรรมวันนี้',
                style: TextStyle(
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final sorted = _todayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded,
                  color: AppColors.corporateBlue, size: r.sp(16)),
              SizedBox(width: r.w(6)),
              Text(
                'สรุปวันนี้',
                style: TextStyle(
                  fontSize: r.sp(12),
                  fontWeight: FontWeight.w900,
                  color: AppColors.corporateBlueDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(8), vertical: r.h(3)),
                decoration: BoxDecoration(
                  color: AppColors.corporateBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(r.r(20)),
                ),
                child: Text(
                  '$_todayTotal รายการ',
                  style: TextStyle(
                    fontSize: r.sp(10),
                    fontWeight: FontWeight.w800,
                    color: AppColors.corporateBlueDark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(10)),
          Wrap(
            spacing: r.w(8),
            runSpacing: r.h(8),
            children: sorted
                .map((e) => _StatChip(
                      r: r,
                      label: _actionLabel(e.key),
                      count: e.value,
                      icon: auditIconFor(e.key),
                      color: auditColorFor(e.key),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _filterSection(Responsive r) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'กรองประเภท',
            style: TextStyle(
              fontSize: r.sp(12),
              fontWeight: FontWeight.w900,
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(8)),
          Wrap(
            spacing: r.w(6),
            runSpacing: r.h(6),
            children: _filters
                .map(
                  (f) => _FilterPill(
                    r: r,
                    label: f.label,
                    selected: _filter == f.action,
                    onTap: () {
                      if (_filter == f.action) return;
                      setState(() => _filter = f.action);
                      _load();
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _logList(Responsive r, double pad, {bool embedded = false}) {
    if (_logs.isEmpty) {
      final empty = GlassCard(
        padding: EdgeInsets.symmetric(
            horizontal: r.w(16), vertical: r.h(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: r.sp(40), color: AppColors.greyLight),
            SizedBox(height: r.h(10)),
            Text(
              'ไม่พบรายการ',
              style: TextStyle(
                fontSize: r.sp(13),
                fontWeight: FontWeight.w800,
                color: AppColors.corporateBlueDark,
              ),
            ),
            SizedBox(height: r.h(4)),
            Text(
              _filter == null
                  ? 'ยังไม่มีบันทึกกิจกรรม'
                  : 'ไม่มีกิจกรรมประเภทนี้',
              style: TextStyle(
                fontSize: r.sp(10),
                color: AppColors.greyMedium,
              ),
            ),
          ],
        ),
      );
      return embedded ? empty : ListView(children: [empty]);
    }

    final groups = _groupByDate(_logs);
    final keys = groups.keys.toList();

    final children = <Widget>[
      if (!embedded)
        Padding(
          padding: EdgeInsets.only(bottom: r.h(8)),
          child: Text(
            'ประวัติกิจกรรม',
            style: TextStyle(
              fontSize: r.sp(12),
              fontWeight: FontWeight.w900,
              color: AppColors.corporateBlueDark,
            ),
          ),
        ),
      for (var i = 0; i < keys.length; i++) ...[
        if (i > 0) SizedBox(height: r.h(10)),
        _DateHeader(r: r, label: keys[i]),
        SizedBox(height: r.h(6)),
        ...groups[keys[i]]!.map((log) => Padding(
              padding: EdgeInsets.only(bottom: r.h(6)),
              child: _LogTile(r: r, log: log),
            )),
      ],
    ];

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }

  Map<String, List<AuditLogEntry>> _groupByDate(List<AuditLogEntry> logs) {
    final map = <String, List<AuditLogEntry>>{};
    for (final log in logs) {
      final key = _dateLabel(log.createdAt.toLocal());
      map.putIfAbsent(key, () => []).add(log);
    }
    return map;
  }

  String _dateLabel(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'วันนี้';
    if (day == today.subtract(const Duration(days: 1))) return 'เมื่อวาน';
    return Fmt.displayDate(local);
  }

  String _actionLabel(String action) {
    return AuditLogEntry(
      id: 0,
      action: action,
      createdAt: DateTime.now(),
    ).actionLabel;
  }
}

IconData auditIconFor(String action) {
  switch (action) {
    case 'login':
      return Icons.login_rounded;
    case 'logout':
      return Icons.logout_rounded;
    case 'sale':
      return Icons.local_gas_station_rounded;
    case 'product_sale':
      return Icons.shopping_bag_rounded;
    case 'print':
      return Icons.print_rounded;
    case 'settings':
      return Icons.settings_rounded;
    case 'backup':
      return Icons.backup_rounded;
    case 'restore':
      return Icons.restore_rounded;
    case 'shift_open':
      return Icons.schedule_rounded;
    case 'shift_close':
      return Icons.event_busy_rounded;
    case 'fuel_import':
      return Icons.local_shipping_rounded;
    default:
      return Icons.history_rounded;
  }
}

Color auditColorFor(String action) {
  switch (action) {
    case 'login':
      return AppColors.success;
    case 'logout':
      return AppColors.greyMedium;
    case 'sale':
      return AppColors.corporateBlue;
    case 'product_sale':
      return AppColors.fuel95;
    case 'print':
      return AppColors.fuel91;
    case 'settings':
      return AppColors.greyDark;
    case 'backup':
      return AppColors.info;
    case 'restore':
      return AppColors.warning;
    case 'shift_open':
      return AppColors.corporateBlue;
    case 'shift_close':
      return AppColors.danger;
    case 'fuel_import':
      return AppColors.fuelSky;
    default:
      return AppColors.corporateBlueDark;
  }
}

class _StatChip extends StatelessWidget {
  final Responsive r;
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.r,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(8)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.r(10)),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: r.sp(14)),
          SizedBox(width: r.w(6)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(width: r.w(6)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.w(6), vertical: r.h(2)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.r(8)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: r.sp(10),
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final Responsive r;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.r,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.corporateBlue : AppColors.softWhite,
      borderRadius: BorderRadius.circular(r.r(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.r(20)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(7)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.r(20)),
            border: Border.all(
              color: selected
                  ? AppColors.corporateBlue
                  : AppColors.greyLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.corporateBlueDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final Responsive r;
  final String label;

  const _DateHeader({required this.r, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: r.w(4),
          height: r.h(14),
          decoration: BoxDecoration(
            color: AppColors.corporateBlue,
            borderRadius: BorderRadius.circular(r.r(2)),
          ),
        ),
        SizedBox(width: r.w(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: r.sp(11),
            fontWeight: FontWeight.w900,
            color: AppColors.corporateBlueDark,
          ),
        ),
        SizedBox(width: r.w(8)),
        const Expanded(
          child: Divider(color: AppColors.greyLight, height: 1),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final Responsive r;
  final AuditLogEntry log;

  const _LogTile({required this.r, required this.log});

  @override
  Widget build(BuildContext context) {
    final color = auditColorFor(log.action);
    final icon = auditIconFor(log.action);
    final time = Fmt.receiptDate(log.createdAt.toLocal());

    return GlassCard(
      padding: EdgeInsets.all(r.w(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: r.w(40),
            height: r.w(40),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.r(10)),
            ),
            child: Icon(icon, color: color, size: r.sp(20)),
          ),
          SizedBox(width: r.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        log.actionLabel,
                        style: TextStyle(
                          fontSize: r.sp(12),
                          fontWeight: FontWeight.w900,
                          color: AppColors.corporateBlueDark,
                        ),
                      ),
                    ),
                    SizedBox(width: r.w(6)),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyMedium,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.h(3)),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: r.sp(11), color: AppColors.greyMedium),
                    SizedBox(width: r.w(3)),
                    Text(
                      log.username ?? 'ระบบ',
                      style: TextStyle(
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w600,
                        color: AppColors.greyDark,
                      ),
                    ),
                  ],
                ),
                if (log.details != null && log.details!.isNotEmpty) ...[
                  SizedBox(height: r.h(6)),
                  _DetailRow(r: r, details: log.details!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final Responsive r;
  final String details;

  const _DetailRow({required this.r, required this.details});

  @override
  Widget build(BuildContext context) {
    final pairs = _parseDetails(details);
    if (pairs.isEmpty) {
      return Text(
        details,
        style: TextStyle(fontSize: r.sp(9), color: AppColors.greyDark),
      );
    }

    return Wrap(
      spacing: r.w(6),
      runSpacing: r.h(4),
      children: pairs
          .map(
            (p) => Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.w(7), vertical: r.h(3)),
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.circular(r.r(6)),
                border: Border.all(color: AppColors.greyLight),
              ),
              child: Text(
                '${p.$1}: ${p.$2}',
                style: TextStyle(
                  fontSize: r.sp(9),
                  fontWeight: FontWeight.w600,
                  color: AppColors.greyDark,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<(String, String)> _parseDetails(String raw) {
    final pairs = <(String, String)>[];
    for (final part in raw.split(' ')) {
      final eq = part.indexOf('=');
      if (eq <= 0 || eq >= part.length - 1) continue;
      final key = _labelKey(part.substring(0, eq));
      final value = part.substring(eq + 1);
      pairs.add((key, value));
    }
    return pairs;
  }

  String _labelKey(String key) {
    switch (key) {
      case 'receipt':
        return 'ใบเสร็จ';
      case 'total':
        return 'ยอด';
      case 'shift_id':
        return 'กะ';
      case 'product':
        return 'สินค้า';
      case 'qty':
        return 'จำนวน';
      default:
        return key;
    }
  }
}
