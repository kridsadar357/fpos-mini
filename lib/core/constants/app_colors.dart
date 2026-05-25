import 'package:flutter/material.dart';

/// Corporate Light Palette — White / Blue / Gray
class AppColors {
  // ============ BRAND PALETTE ============
  static const Color corporateBlue = Color(0xFF1E56A0);
  static const Color corporateBlueDark = Color(0xFF163172);
  static const Color lightBlue = Color(0xFFD6E4F0);
  static const Color softWhite = Color(0xFFF6F6F6);
  
  static const Color black = Color(0xFF1A1A1A);
  static const Color greyDark = Color(0xFF4A4A4A);
  static const Color greyMedium = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFE0E0E0);
  static const Color white = Color(0xFFFFFFFF);

  // ============ SEMANTIC TOKENS ============
  static const Color primary = corporateBlue;
  static const Color secondary = Color(0xFF1E56A0);
  static const Color background = Color(0xFFE9EEF2); // Light Gray-Blue background
  static const Color surface = white;
  static const Color surfaceAlt = Color(0xFFF8F9FA);
  
  static const Color onPrimary = white;
  static const Color onSurface = black;

  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);

  // ============ FUEL TYPE ACCENTS (MATCHING REFERENCE) ============
  static const Color fuel95 = Color(0xFFF37021);      // Orange
  static const Color fuel91 = Color(0xFF2B7A3E);      // Green
  static const Color fuelBenzene = Color(0xFF1E3D59); // Dark Blue
  static const Color fuelDiesel = Color(0xFF1E3D59);  // Alias for Benzene/Diesel
  static const Color fuelE20 = Color(0xFF8BC34A);     // Light Green
  static const Color fuelSky = Color(0xFF3AB0FF);     // Sky Blue

  // ============ LEGACY COMPATIBILITY ALIASES ============
  static const Color gold = fuel95;
  static const Color softGrey = greyMedium;
  static const Color charcoal = corporateBlueDark;
  static const Color redBright = danger;
  static const Color red = danger;
  static const Color goldDark = corporateBlueDark;
  static const Color goldLight = lightBlue;
  static const Color redDark = Color(0xFF8B0000);
  
  static const LinearGradient goldGradient = LinearGradient(
    colors: [fuel95, Color(0xFFFF9E5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blackGradient = LinearGradient(
    colors: [black, Color(0xFF333333)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
