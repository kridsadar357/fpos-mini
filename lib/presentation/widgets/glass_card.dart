import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? borderRadius;
  final VoidCallback? onTap;

  final double? blur; // Legacy compatibility
  final Gradient? gradient; // Legacy compatibility
  final Border? border; // Legacy compatibility

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.onTap,
    this.blur,
    this.gradient,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    
    Widget content = Container(
      padding: padding ?? EdgeInsets.all(r.w(16)),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? r.r(16)),
        border: Border.all(
          color: AppColors.greyLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? r.r(16)),
          child: content,
        ),
      );
    }

    return content;
  }
}
