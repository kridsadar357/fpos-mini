import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

class PosHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool compact;

  const PosHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onBack,
    this.compact = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(compact ? 52 : 72);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.corporateBlueDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: compact ? 4 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        r.w(compact ? 8 : 12),
        r.h(compact ? 4 : 6),
        r.w(compact ? 8 : 12),
        r.h(compact ? 6 : 8),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: r.w(compact ? 32 : 40),
                minHeight: r.h(compact ? 32 : 40),
              ),
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.white, size: r.sp(compact ? 20 : 24)),
              onPressed: onBack,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: r.sp(compact ? 15 : 18),
                    fontWeight: FontWeight.w900,
                    letterSpacing: compact ? 0.4 : 0.8,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.8),
                      fontSize: r.sp(compact ? 10 : 12),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    DateFormat('EEE, dd MMM yyyy • HH:mm').format(now),
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.7),
                      fontSize: r.sp(compact ? 9 : 11),
                    ),
                  ),
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}
