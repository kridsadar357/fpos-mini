import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/license_features.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../providers/app_state.dart';
import '../../widgets/pos_header.dart';
import 'audit_log_screen.dart';
import 'backup_settings_screen.dart';
import 'daily_overview_screen.dart';
import 'dispenser_nozzle_settings_screen.dart';
import 'fuel_import_screen.dart';
import 'fuel_price_settings_screen.dart';
import 'general_settings_screen.dart';
import 'inventory_settings_screen.dart';
import 'printer_settings_screen.dart';
import 'product_settings_screen.dart';
import 'product_stock_report_screen.dart';
import 'promotion_settings_screen.dart';
import 'sales_report_screen.dart';
import 'users_settings_screen.dart';

class BackendHomeScreen extends StatefulWidget {
  const BackendHomeScreen({super.key});

  @override
  State<BackendHomeScreen> createState() => _BackendHomeScreenState();
}

class _BackendHomeScreenState extends State<BackendHomeScreen> {
  DailySummary? _today;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    final summary = await TransactionRepository().dailySummary(DateTime.now());
    if (!mounted) return;
    setState(() => _today = summary);
  }

  List<_MenuSection> _sections(LicenseTier tier) {
    return [
      const _MenuSection(
        title: 'รายงาน',
        items: [
          _MenuItem(
            icon: Icons.insights_rounded,
            label: 'ภาพรวมรายวัน',
            color: AppColors.corporateBlue,
            screen: DailyOverviewScreen(),
          ),
          _MenuItem(
            icon: Icons.receipt_long_rounded,
            label: 'รายงานการขาย',
            color: AppColors.info,
            screen: SalesReportScreen(),
          ),
          _MenuItem(
            icon: Icons.history_rounded,
            label: 'บันทึกกิจกรรม',
            color: AppColors.greyDark,
            screen: AuditLogScreen(),
          ),
        ],
      ),
      _MenuSection(
        title: 'น้ำมัน & สินค้า',
        items: [
          if (LicenseFeatures.isEnabled(tier, AppFeature.fuelImport))
            const _MenuItem(
              icon: Icons.local_shipping_rounded,
              label: 'นำเข้าน้ำมัน',
              color: AppColors.fuelBenzene,
              screen: FuelImportScreen(),
            ),
          if (LicenseFeatures.showFuelInventoryMenu(tier))
            const _MenuItem(
              icon: Icons.inventory_2_rounded,
              label: 'คลังน้ำมัน',
              color: AppColors.corporateBlue,
              screen: InventorySettingsScreen(),
            ),
          if (LicenseFeatures.isEnabled(tier, AppFeature.productManagement))
            const _MenuItem(
              icon: Icons.shopping_bag_rounded,
              label: 'จัดการสินค้า',
              color: AppColors.fuel91,
              screen: ProductSettingsScreen(),
            ),
          if (LicenseFeatures.isEnabled(tier, AppFeature.productStock))
            const _MenuItem(
              icon: Icons.inventory_rounded,
              label: 'คลังสินค้า',
              color: AppColors.fuel91,
              screen: ProductStockReportScreen(),
            ),
          const _MenuItem(
            icon: Icons.oil_barrel_rounded,
            label: 'ตู้จ่ายและมือจ่าย',
            color: AppColors.fuel95,
            screen: DispenserNozzleSettingsScreen(),
          ),
          if (LicenseFeatures.isEnabled(tier, AppFeature.promotions))
            const _MenuItem(
              icon: Icons.redeem_rounded,
              label: 'โปรโมชั่น',
              color: AppColors.fuel95,
              screen: PromotionSettingsScreen(),
            ),
          const _MenuItem(
            icon: Icons.price_change_rounded,
            label: 'ราคาน้ำมัน',
            color: AppColors.corporateBlueDark,
            screen: FuelPriceSettingsScreen(),
          ),
        ],
      ),
      const _MenuSection(
        title: 'ระบบ',
        items: [
          _MenuItem(
            icon: Icons.print_rounded,
            label: 'เครื่องพิมพ์',
            color: AppColors.corporateBlue,
            screen: PrinterSettingsScreen(),
          ),
          _MenuItem(
            icon: Icons.cloud_upload_rounded,
            label: 'สำรองข้อมูล',
            color: AppColors.info,
            screen: BackupSettingsScreen(),
          ),
          _MenuItem(
            icon: Icons.people_rounded,
            label: 'ผู้ใช้งาน',
            color: AppColors.corporateBlueDark,
            screen: UsersSettingsScreen(),
          ),
          _MenuItem(
            icon: Icons.tune_rounded,
            label: 'ตั้งค่าทั่วไป',
            color: AppColors.greyMedium,
            screen: GeneralSettingsScreen(),
          ),
        ],
      ),
    ];
  }

  int _columnCount(double width) {
    if (width >= 1100) return 5;
    if (width >= 820) return 4;
    if (width >= 560) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final tier = state.licenseTier;
    final sections = _sections(tier);
    final pad = r.w(8);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'ระบบหลังบ้าน',
        subtitle:
            '${state.user?.displayName ?? 'ผู้ดูแลระบบ'} · ${LicenseFeatures.tierLabel(tier)}',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cols = _columnCount(constraints.maxWidth);
          final gap = r.h(6);

          return RefreshIndicator(
            onRefresh: _loadToday,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pad, r.h(6), pad, r.h(6)),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompactSummaryBar(summary: _today, r: r),
                    SizedBox(height: gap),
                    for (var si = 0; si < sections.length; si++) ...[
                      if (si > 0) SizedBox(height: gap),
                      _SectionLabel(title: sections[si].title, r: r),
                      SizedBox(height: r.h(4)),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: r.w(6),
                          childAspectRatio: cols >= 4 ? 3.4 : 3.0,
                        ),
                        itemCount: sections[si].items.length,
                        itemBuilder: (context, i) =>
                            _CompactMenuTile(item: sections[si].items[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuSection {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.screen,
  });
}

class _CompactSummaryBar extends StatelessWidget {
  final DailySummary? summary;
  final Responsive r;

  const _CompactSummaryBar({required this.summary, required this.r});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      height: r.h(52).clamp(46.0, 56.0),
      padding: EdgeInsets.symmetric(horizontal: r.w(12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.corporateBlueDark, AppColors.corporateBlue],
        ),
        borderRadius: BorderRadius.circular(r.r(10)),
      ),
      child: Row(
        children: [
          Icon(Icons.today_rounded, color: AppColors.white, size: r.sp(20)),
          SizedBox(width: r.w(8)),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ยอดขายวันนี้',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontSize: r.sp(9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  s == null ? '…' : Fmt.money(s.total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: r.sp(16),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _StatChip(
            label: 'รายการ',
            value: s == null ? '—' : '${s.count}',
            r: r,
          ),
          SizedBox(width: r.w(6)),
          _StatChip(
            label: 'ลิตร',
            value: s == null ? '—' : Fmt.liters(s.liters).replaceAll(' L', ''),
            r: r,
          ),
          SizedBox(width: r.w(6)),
          _StatChip(
            label: 'สินค้า',
            value: s == null ? '—' : Fmt.moneyPlain(s.productTotal),
            r: r,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Responsive r;

  const _StatChip({
    required this.label,
    required this.value,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(4)),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.8),
              fontSize: r.sp(8),
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.white,
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final Responsive r;

  const _SectionLabel({required this.title, required this.r});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: r.h(14),
          decoration: BoxDecoration(
            color: AppColors.corporateBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.w(6)),
        Text(
          title,
          style: TextStyle(
            fontSize: r.sp(11),
            fontWeight: FontWeight.w800,
            color: AppColors.corporateBlueDark,
          ),
        ),
      ],
    );
  }
}

class _CompactMenuTile extends StatelessWidget {
  final _MenuItem item;

  const _CompactMenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(r.r(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.r(8)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => item.screen),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.r(8)),
            border: Border.all(color: AppColors.greyLight),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r.r(8)),
                    bottomLeft: Radius.circular(r.r(8)),
                  ),
                ),
              ),
              SizedBox(width: r.w(6)),
              Container(
                width: r.w(32),
                height: r.w(32),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: r.sp(17)),
              ),
              SizedBox(width: r.w(6)),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: r.sp(18),
                color: AppColors.greyMedium,
              ),
              SizedBox(width: r.w(2)),
            ],
          ),
        ),
      ),
    );
  }
}
