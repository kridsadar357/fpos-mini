import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../utils/responsive.dart';

/// Enterprise theme using bundled Prompt font (offline-safe for POS).
class AppTheme {
  static const fontFamily = 'Prompt';

  static ThemeData build(BuildContext context) {
    final r = Responsive.of(context);

    // Global scale correction for iPad pro (prevents overflow)
    final double scale = r.isTablet ? 0.9 : 1.0;

    TextStyle prompt({
      double? fontSize,
      FontWeight? fontWeight,
      Color? color,
      double? letterSpacing,
      double? height,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.corporateBlueDark,
        onSecondary: AppColors.white,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.danger,
        onError: AppColors.white,
      ),
      fontFamily: fontFamily,
      textTheme: TextTheme(
        displayLarge: prompt(
          fontSize: r.sp(42 * scale),
          fontWeight: FontWeight.w900,
          color: AppColors.corporateBlueDark,
        ),
        displayMedium: prompt(
          fontSize: r.sp(32 * scale),
          fontWeight: FontWeight.w800,
          color: AppColors.corporateBlueDark,
        ),
        headlineLarge: prompt(
          fontSize: r.sp(26 * scale),
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
        headlineMedium: prompt(
          fontSize: r.sp(20 * scale),
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
        titleLarge: prompt(
          fontSize: r.sp(18 * scale),
          fontWeight: FontWeight.w600,
          color: AppColors.black,
        ),
        titleMedium: prompt(
          fontSize: r.sp(16 * scale),
          fontWeight: FontWeight.w600,
          color: AppColors.greyDark,
        ),
        bodyLarge: prompt(
          fontSize: r.sp(15 * scale),
          color: AppColors.black,
        ),
        bodyMedium: prompt(
          fontSize: r.sp(13 * scale),
          color: AppColors.greyDark,
        ),
        labelLarge: prompt(
          fontSize: r.sp(14 * scale),
          fontWeight: FontWeight.w700,
          color: AppColors.black,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.corporateBlueDark,
        foregroundColor: AppColors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: prompt(
          fontSize: r.sp(20 * scale),
          fontWeight: FontWeight.w800,
          color: AppColors.white,
          letterSpacing: 1.0,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.r(16)),
          side: const BorderSide(color: AppColors.greyLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.corporateBlue,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(14)),
          minimumSize: Size(r.w(120), r.h(52)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.r(12)),
          ),
          textStyle: prompt(
            fontSize: r.sp(17 * scale),
            fontWeight: FontWeight.w800,
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.corporateBlue,
          side: const BorderSide(color: AppColors.corporateBlue, width: 2),
          padding: EdgeInsets.symmetric(horizontal: r.w(18), vertical: r.h(12)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.r(12)),
          ),
          textStyle: prompt(
            fontSize: r.sp(15 * scale),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.r(12)),
          borderSide: const BorderSide(color: AppColors.greyLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.r(12)),
          borderSide: const BorderSide(color: AppColors.greyLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.r(12)),
          borderSide: const BorderSide(color: AppColors.corporateBlue, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.greyDark,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: r.w(16),
          vertical: r.h(14),
        ),
      ),
    );
  }
}
