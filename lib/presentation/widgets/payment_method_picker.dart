import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';

/// ตัวเลือกช่องทางชำระเงิน — กริด 2×2 ไม่ล้นจอ
class PaymentMethodPicker extends StatelessWidget {
  final void Function(PaymentMethod method) onSelected;

  const PaymentMethodPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    const methods = PaymentMethod.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 420;
        final crossCount = wide ? 4 : 2;
        final tileHeight = crossCount == 4 ? r.h(88.0) : r.h(96.0);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: r.w(10),
            mainAxisSpacing: r.h(10),
            mainAxisExtent: tileHeight,
          ),
          itemCount: methods.length,
          itemBuilder: (context, i) {
            final m = methods[i];
            return _PaymentTile(
              method: m,
              onTap: () => onSelected(m),
            );
          },
        );
      },
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentMethod method;
  final VoidCallback onTap;

  const _PaymentTile({required this.method, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final iconSize = (h * 0.34).clamp(20.0, r.sp(26));
        final fontSize = (h * 0.13).clamp(10.0, r.sp(12));
        final gap = (h * 0.05).clamp(2.0, r.h(6));

        return Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 2,
          shadowColor: AppColors.corporateBlue.withValues(alpha: 0.15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.corporateBlue.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.06,
                  vertical: h * 0.08,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      method.icon,
                      color: AppColors.corporateBlue,
                      size: iconSize,
                    ),
                    SizedBox(height: gap),
                    Text(
                      method.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.corporateBlueDark,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
