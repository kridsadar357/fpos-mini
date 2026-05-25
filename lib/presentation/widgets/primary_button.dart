import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

enum ButtonVariant { primary, secondary, outline, ghost }

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final bool expand;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.expand = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    Color bg;
    Color fg;
    Border? border;
    switch (variant) {
      case ButtonVariant.primary:
        bg = AppColors.red; fg = AppColors.white; break;
      case ButtonVariant.secondary:
        bg = AppColors.gold; fg = AppColors.black; break;
      case ButtonVariant.outline:
        bg = AppColors.white;
        fg = AppColors.corporateBlueDark;
        border = Border.all(color: AppColors.corporateBlue, width: 2);
        break;
      case ButtonVariant.ghost:
        bg = AppColors.surfaceAlt; fg = AppColors.white; break;
    }

    final child = Material(
      color: bg,
      borderRadius: BorderRadius.circular(r.r(14)),
      elevation: variant == ButtonVariant.outline ? 0 : 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(r.r(14)),
        onTap: loading ? null : onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: r.h(52)),
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(r.r(12)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: r.w(16),
            vertical: r.h(14),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: r.sp(20),
                  height: r.sp(20),
                  child: CircularProgressIndicator(
                    color: fg,
                    strokeWidth: 3,
                  ),
                )
              else if (icon != null) ...[
                Icon(icon, color: fg, size: r.sp(22)),
                SizedBox(width: r.w(8)),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: fg,
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!expand) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite || w <= 0) {
          return child;
        }
        return SizedBox(width: w, child: child);
      },
    );
  }
}
