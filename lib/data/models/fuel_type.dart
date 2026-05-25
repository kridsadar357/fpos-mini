import 'package:flutter/material.dart';

class FuelType {
  final int id;
  final String code;
  final String name;
  final double pricePerLiter;
  final String? colorHex;
  final bool isActive;

  FuelType({
    required this.id,
    required this.code,
    required this.name,
    required this.pricePerLiter,
    this.colorHex,
    this.isActive = true,
  });

  Color get color {
    if (colorHex == null) return const Color(0xFFD4AF37);
    final hex = colorHex!.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory FuelType.fromMap(Map<String, Object?> m) => FuelType(
        id: m['id'] as int,
        code: m['code'] as String,
        name: m['name'] as String,
        pricePerLiter: (m['price_per_liter'] as num).toDouble(),
        colorHex: m['color_hex'] as String?,
        isActive: (m['is_active'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'price_per_liter': pricePerLiter,
        'color_hex': colorHex,
        'is_active': isActive ? 1 : 0,
      };
}
