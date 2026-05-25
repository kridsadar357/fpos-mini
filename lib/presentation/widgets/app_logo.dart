import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';

/// Brand logo for Fuel POS — tablet/mobile point of sale.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final bool showTagline;
  final Color? nameColor;
  final Color? taglineColor;

  const AppLogo({
    super.key,
    required this.size,
    this.showName = false,
    this.showTagline = false,
    this.nameColor,
    this.taglineColor,
  });

  static const String assetPath = 'assets/images/app_logo.png';

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.corporateBlue.withValues(alpha: 0.2),
                blurRadius: size * 0.12,
                offset: Offset(0, size * 0.04),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 2).round(),
              cacheHeight: (size * 2).round(),
            ),
          ),
        ),
        if (showName) ...[
          SizedBox(height: r.h(8)),
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: r.sp(size * 0.22),
              fontWeight: FontWeight.w900,
              color: nameColor ?? AppColors.corporateBlueDark,
              letterSpacing: 2,
            ),
          ),
        ],
        if (showTagline) ...[
          SizedBox(height: r.h(2)),
          Text(
            'ระบบขายน้ำมัน • Mobile & Tablet',
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: FontWeight.w600,
              color: taglineColor ?? AppColors.greyDark,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Login hero: logo + app name on branded card.
class AppLogoHero extends StatelessWidget {
  const AppLogoHero({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final logoSize = r.isTablet ? r.w(120) : r.w(100);

    return Container(
      constraints: BoxConstraints(minHeight: r.h(160)),
      padding: EdgeInsets.symmetric(vertical: r.h(24), horizontal: r.w(24)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.white, AppColors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.r(24)),
        border: Border.all(color: AppColors.corporateBlue.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.corporateBlue.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: AppLogo(
          size: logoSize,
          showName: true,
          showTagline: true,
        ),
      ),
    );
  }
}
