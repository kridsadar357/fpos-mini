import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/fuel_color_util.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/tank.dart';
import '../glass_card.dart';

/// คลังน้ำมัน — แท่งแนวตั้งกระชับ แสดง % และลิตรครบ
class TankInventoryPanel extends StatelessWidget {
  final List<Tank> tanks;

  const TankInventoryPanel({super.key, required this.tanks});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final shown = tanks.take(4).toList();

    return GlassCard(
      padding: EdgeInsets.fromLTRB(r.w(8), r.w(6), r.w(8), r.w(6)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'คลังน้ำมัน',
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontSize: r.sp(12),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: r.h(4)),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'ไม่มีข้อมูลถัง',
                  style: TextStyle(color: AppColors.greyMedium, fontSize: 11),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final barH = (r.h(60)).clamp(44.0, 64.0);
                final blockH = barH + r.h(38);

                return SizedBox(
                  height: blockH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) SizedBox(width: r.w(4)),
                        Expanded(
                          child: _VerticalTank(
                            tank: shown[i],
                            maxHeight: blockH,
                            targetBarH: barH,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VerticalTank extends StatelessWidget {
  final Tank tank;
  final double maxHeight;
  final double targetBarH;

  const _VerticalTank({
    required this.tank,
    required this.maxHeight,
    required this.targetBarH,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pct = tank.capacity > 0
        ? (tank.currentLiters / tank.capacity).clamp(0.0, 1.0)
        : 0.0;
    var color = fuelColorForTank(
      colorHex: tank.colorHex,
      fuelName: tank.fuelName,
      tankName: tank.name,
    );
    final low = pct < 0.15;
    if (low) color = AppColors.danger;
    final fuelTag = tank.fuelName != null
        ? shortFuelLabel(tank.fuelName!)
        : null;
    final label = (fuelTag != null && fuelTag.isNotEmpty)
        ? '${tank.name} · $fuelTag'
        : tank.name;
    final pctText = '${(pct * 100).toInt()}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final barH =
            (constraints.maxHeight - r.h(36)).clamp(36.0, targetBarH);

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: barH,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 28,
                        height: barH,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          border: Border.all(color: AppColors.greyLight),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                      Container(
                        width: 25,
                        height: barH * pct.clamp(0.1, 1.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(2),
                          ),
                        ),
                        child: Text(
                          pctText,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.h(2)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(9),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${tank.currentLiters.toInt()}/${tank.capacity.toInt()}L',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: low ? AppColors.danger : AppColors.greyDark,
                    fontSize: r.sp(8),
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
                if (low)
                  Text(
                    'ต่ำ',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: r.sp(7),
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
