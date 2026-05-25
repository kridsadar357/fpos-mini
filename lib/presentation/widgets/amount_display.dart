import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';

class AmountDisplay extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Color accent;
  final IconData? icon;

  const AmountDisplay({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.accent = AppColors.corporateBlue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.all(r.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(r.r(16)),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.corporateBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: accent, size: r.sp(20)),
                SizedBox(width: r.w(8)),
              ],
              Text(
                label,
                style: TextStyle(
                  color: AppColors.greyDark,
                  fontSize: r.sp(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(8)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  AppConstants.currencySymbol,
                  style: TextStyle(
                    color: accent,
                    fontSize: r.sp(22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: r.w(6)),
                Text(
                  value.isEmpty ? '0.00' : value,
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(40),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (hint != null) ...[
            SizedBox(height: r.h(6)),
            Text(
              hint!,
              style: TextStyle(
                color: AppColors.greyMedium,
                fontSize: r.sp(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
