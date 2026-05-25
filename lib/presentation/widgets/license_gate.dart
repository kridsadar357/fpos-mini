import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/license_features.dart';
import '../../core/utils/responsive.dart';
import '../providers/app_state.dart';
import 'glass_card.dart';
import 'pos_header.dart';

/// Blocks screen content when the current license tier lacks [feature].
class LicenseGate extends StatelessWidget {
  final AppFeature feature;
  final String title;
  final Widget child;

  const LicenseGate({
    super.key,
    required this.feature,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.canUse(feature)) return child;

    final r = Responsive.of(context);
    final tierLabel = LicenseFeatures.tierLabel(state.licenseTier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: title,
        subtitle: 'Package $tierLabel — ไม่รวมในแพ็กเกจนี้',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(r.w(24)),
          child: GlassCard(
            padding: EdgeInsets.all(r.w(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded,
                    size: r.sp(48), color: AppColors.greyMedium),
                SizedBox(height: r.h(12)),
                Text(
                  'ฟีเจอร์ไม่พร้อมใช้งาน',
                  style: TextStyle(
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.w900,
                    color: AppColors.corporateBlueDark,
                  ),
                ),
                SizedBox(height: r.h(6)),
                Text(
                  'Package ปัจจุบัน: $tierLabel\n'
                  'อัปเกรด License หรือกด「ตรวจสอบ License ใหม่」ใน ตั้งค่าทั่วไป',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.sp(11),
                    color: AppColors.greyMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
