import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/license_features.dart';
import '../../../core/utils/responsive.dart';
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
import 'users_settings_screen.dart';

class BackendHomeScreen extends StatelessWidget {
  const BackendHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final tier = state.licenseTier;

    final tiles = <_MenuItem>[
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
      const _MenuItem(
        icon: Icons.insights_rounded,
        label: 'ภาพรวมรายวัน',
        color: AppColors.corporateBlue,
        screen: DailyOverviewScreen(),
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
      const _MenuItem(
        icon: Icons.print_rounded,
        label: 'เครื่องพิมพ์',
        color: AppColors.corporateBlue,
        screen: PrinterSettingsScreen(),
      ),
      const _MenuItem(
        icon: Icons.backup_rounded,
        label: 'สำรองข้อมูล',
        color: AppColors.info,
        screen: BackupSettingsScreen(),
      ),
      const _MenuItem(
        icon: Icons.people_rounded,
        label: 'ผู้ใช้งาน',
        color: AppColors.corporateBlueDark,
        screen: UsersSettingsScreen(),
      ),
      const _MenuItem(
        icon: Icons.history_rounded,
        label: 'บันทึกกิจกรรม',
        color: AppColors.greyDark,
        screen: AuditLogScreen(),
      ),
      const _MenuItem(
        icon: Icons.settings_rounded,
        label: 'ตั้งค่าทั่วไป',
        color: AppColors.greyMedium,
        screen: GeneralSettingsScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'ระบบหลังบ้าน',
        subtitle:
            '${state.user?.displayName ?? 'ผู้ดูแลระบบ'} · ${LicenseFeatures.tierLabel(tier)}',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = tiles.length;
            final pad = r.w(12);
            final spacing = r.h(8);

            int cols = 2;
            if (constraints.maxWidth >= 900) {
              cols = 4;
            } else if (constraints.maxWidth >= 560) {
              cols = 3;
            }

            final rows = (count / cols).ceil();
            final gridW = constraints.maxWidth - pad * 2;
            final gridH = constraints.maxHeight - pad * 2;
            final cellW = (gridW - spacing * (cols - 1)) / cols;
            final cellH = (gridH - spacing * (rows - 1)) / rows;
            final aspect = (cellW / cellH).clamp(1.35, 2.4);

            return Padding(
              padding: EdgeInsets.all(pad),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: aspect,
                ),
                itemCount: count,
                itemBuilder: (context, i) {
                  final t = tiles[i];
                  return _BackendMenuTile(item: t);
                },
              ),
            );
          },
        ),
      ),
    );
  }
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

class _BackendMenuTile extends StatelessWidget {
  final _MenuItem item;

  const _BackendMenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(r.r(12)),
      elevation: 1,
      shadowColor: AppColors.corporateBlue.withValues(alpha: 0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.r(12)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => item.screen),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.r(12)),
            border: Border.all(
              color: item.color.withValues(alpha: 0.25),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: r.w(10),
            vertical: r.h(8),
          ),
          child: Row(
            children: [
              Container(
                width: r.w(40),
                height: r.w(40),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: r.sp(22)),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.greyMedium,
                size: r.sp(20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
