import '../constants/app_colors.dart';
import 'package:flutter/material.dart';

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return null;
  }
}

/// Maps fuel display names (Thai/English) to brand accent colors.
Color fuelColorForName(String name) {
  final n = name.toLowerCase();
  // ตรวจ 95 ก่อน 91 เพราะบางชื่อมีตัวเลขซ้อนกัน
  if (n.contains('95') || n.contains('e85')) return AppColors.fuel95;
  if (n.contains('91') || n.contains('e10')) return AppColors.fuel91;
  if (n.contains('e20')) return AppColors.fuelE20;
  if (n.contains('diesel') ||
      n.contains('ดีเซล') ||
      n.contains('b7') ||
      n.contains('benzene')) {
    return AppColors.fuelBenzene;
  }
  if (n.contains('euro') || n.contains('sky')) return AppColors.fuelSky;
  return AppColors.corporateBlue;
}

/// ใช้สีจาก DB (`color_hex`) ถ้ามี ไม่งั้น map จากชื่อน้ำมัน
Color fuelColorFromHex(String? hex, {String? fallbackName}) {
  final parsed = _parseHexColor(hex);
  if (parsed != null) return parsed;
  return fuelColorForName(fallbackName ?? '');
}

/// ใช้สีจาก nozzle row (มี color_hex + fuel_name)
Color fuelColorFromNozzle(Map<String, dynamic> nozzle) {
  return fuelColorFromHex(
    nozzle['color_hex']?.toString(),
    fallbackName: nozzle['fuel_name']?.toString(),
  );
}

/// สีถัง/คลัง — อิงชนิดน้ำมัน ไม่ใช่ชื่อถัง
Color fuelColorForTank({
  String? colorHex,
  String? fuelName,
  String? tankName,
}) {
  return fuelColorFromHex(colorHex, fallbackName: fuelName ?? tankName ?? '');
}

/// ชื่อสั้นสำหรับปุ่มมือจ่าย (ไม่ให้ข้อความถูกตัด)
String shortFuelLabel(String name) {
  final m = RegExp(r'(\d{2,3}|B\d+|E\d+)').firstMatch(name);
  if (m != null) return m.group(1)!;
  if (name.contains('ดีเซล')) return 'ดีเซล';
  if (name.contains('91')) return '91';
  if (name.contains('95')) return '95';
  if (name.length <= 8) return name;
  return name.substring(0, 8);
}
