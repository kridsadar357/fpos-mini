import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../glass_card.dart';

/// ราคาน้ำมันแบบกระชับ — ไม่มีกราฟ/scroll
class MarketPricePanel extends StatelessWidget {
  final List<Map<String, dynamic>> fuelPrices;

  const MarketPricePanel({super.key, required this.fuelPrices});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return GlassCard(
      padding: EdgeInsets.all(r.w(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ราคาน้ำมัน',
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontSize: r.sp(13),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: r.h(6)),
          Expanded(
            child: fuelPrices.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่มีข้อมูล',
                      style: TextStyle(
                        color: AppColors.greyMedium,
                        fontSize: 11,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < fuelPrices.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: i < fuelPrices.length - 1 ? r.h(4) : 0,
                            ),
                            child: _PriceRow(
                              name: fuelPrices[i]['name']?.toString() ?? '',
                              price: (fuelPrices[i]['price_per_liter'] as num)
                                  .toDouble(),
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
}

class _PriceRow extends StatelessWidget {
  final String name;
  final double price;

  const _PriceRow({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(8),
        vertical: r.h(4),
      ),
      decoration: BoxDecoration(
        color: AppColors.corporateBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w600,
                  color: AppColors.corporateBlueDark,
                ),
              ),
            ),
          ),
          Text(
            Fmt.money(price),
            style: TextStyle(
              fontSize: r.sp(12),
              fontWeight: FontWeight.w900,
              color: AppColors.corporateBlue,
            ),
          ),
        ],
      ),
    );
  }
}
