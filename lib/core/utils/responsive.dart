import 'package:flutter/material.dart';

/// Responsive engine — perfectly calculates resolution / pixel density / orientation
/// BEFORE any widget is rendered. Used to scale UI (width, height, radius, sp)
/// so elements stay "big and compact" across phones and tablets.
///
/// Reference design: 390 x 844 logical px (iPhone 14 Pro) — industry standard for POS.
class Responsive {
  final double width;
  final double height;
  final double shortestSide;
  final double longestSide;
  final double aspectRatio;
  final double devicePixelRatio;
  final EdgeInsets safeInsets;
  final Orientation orientation;
  final bool isTablet;
  final double textScaleFactor;

  Responsive._({
    required this.width,
    required this.height,
    required this.shortestSide,
    required this.longestSide,
    required this.aspectRatio,
    required this.devicePixelRatio,
    required this.safeInsets,
    required this.orientation,
    required this.isTablet,
    required this.textScaleFactor,
  });

  // Reference dimensions — Industry standard for POS design
  static const double _refShort = 390.0;
  static const double _refLong = 844.0;

  factory Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final short = size.shortestSide;
    final long = size.longestSide;
    // Derive a scalar compatible with modern Flutter text scaling.
    final scaler = MediaQuery.textScalerOf(context).scale(1.0);

    return Responsive._(
      width: size.width,
      height: size.height,
      shortestSide: short,
      longestSide: long,
      aspectRatio: size.aspectRatio,
      devicePixelRatio: mq.devicePixelRatio,
      safeInsets: mq.padding,
      orientation: mq.orientation,
      isTablet: short >= 600,
      textScaleFactor: scaler.clamp(0.9, 1.2),
    );
  }

  /// Scale width-relative value.
  /// Uses a stabilized logic that prevents "bloating" on wide screens.
  double w(double v) {
    final isLandscape = width > height;
    final scale = (isLandscape ? height : width) / _refShort;
    // Further decreased scale for tablets
    return v * (isTablet ? scale.clamp(1.0, 1.4) : scale);
  }

  /// Scale height-relative value.
  /// Correctly handles the long axis across different orientations.
  double h(double v) {
    final isLandscape = width > height;
    final scale = (isLandscape ? width : height) / _refLong;
    // Further decreased scale for tablets
    return v * (isTablet ? scale.clamp(1.0, 1.2) : scale);
  }

  /// Radius — based on shortest side, avoids stretching on tablets.
  double r(double v) => (v / _refShort) * shortestSide * (isTablet ? 0.75 : 1.0);

  /// Scalable font size — honors system text scale factor but capped.
  double sp(double v) {
    final base = (v / _refShort) * shortestSide;
    // Significantly dampened tablet font scaling
    final tabletDampen = isTablet ? 0.65 : 1.0;
    return base * tabletDampen * textScaleFactor;
  }

  /// Square tappable target.
  double tap(double v) {
    final baseMulti = isTablet ? 0.8 : 1.0;
    final computed = (v / _refShort) * shortestSide * baseMulti;
    return computed < 56 ? 56 : computed;
  }
}
