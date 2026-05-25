class Promotion {
  final int id;
  final String name;
  final String? description;
  final String type; // percent | fixed | per_liter | free_product
  final double value;
  final double minAmount;
  final int? fuelTypeId;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final DateTime createdAt;
  final int? rewardProductId;
  final int rewardQty;
  final String? rewardProductName;
  final double? rewardProductPrice;

  Promotion({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.value,
    this.minAmount = 0,
    this.fuelTypeId,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    required this.createdAt,
    this.rewardProductId,
    this.rewardQty = 1,
    this.rewardProductName,
    this.rewardProductPrice,
  });

  bool get isFreeProduct => type == 'free_product';

  bool appliesTo({required int fuelId, required double subtotal, DateTime? when}) {
    if (!isActive) return false;
    if (subtotal < minAmount) return false;
    if (fuelTypeId != null && fuelTypeId != fuelId) return false;
    if (isFreeProduct && rewardProductId == null) return false;
    final now = when ?? DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  /// จำนวนแถมตามยอดเติม — เช่น เติม 500 แถม 1, เติม 2000 ได้ 4
  int computedRewardQty(double subtotal) {
    if (!isFreeProduct || rewardProductId == null) return 0;
    if (subtotal <= 0) return 0;
    if (minAmount <= 0) return rewardQty;
    final tiers = (subtotal / minAmount).floor();
    if (tiers <= 0) return 0;
    return tiers * rewardQty;
  }

  double computeDiscount({required double subtotal, required double liters}) {
    switch (type) {
      case 'percent':
        return (subtotal * value / 100).clamp(0, subtotal);
      case 'fixed':
        return value.clamp(0, subtotal);
      case 'per_liter':
        return (liters * value).clamp(0, subtotal);
      case 'free_product':
        return 0;
    }
    return 0;
  }

  /// ใช้เปรียบเทียบโปรที่คุ้มที่สุด
  double rankingValue({required double subtotal, required double liters}) {
    if (isFreeProduct) {
      final price = rewardProductPrice ?? 0;
      return price * computedRewardQty(subtotal);
    }
    return computeDiscount(subtotal: subtotal, liters: liters);
  }

  /// มูลค่าที่หักจากยอดขายจริง
  double effectiveDiscountAmount({
    required double subtotal,
    required double liters,
  }) {
    if (isFreeProduct) return 0;
    return computeDiscount(subtotal: subtotal, liters: liters);
  }

  String freeProductLabel({double? subtotal}) {
    final product = rewardProductName ?? 'สินค้า';
    final qty = subtotal != null ? computedRewardQty(subtotal) : rewardQty;
    if (qty <= 0) return '';
    if (qty > 1) return 'แถม$product x$qty';
    return 'แถม$product';
  }

  String benefitSummary({double? subtotal}) {
    switch (type) {
      case 'percent':
        return 'ลด ${value.toStringAsFixed(1)}%';
      case 'fixed':
        return 'ลด ${value.toStringAsFixed(2)} บาท';
      case 'per_liter':
        return 'ลด ${value.toStringAsFixed(2)} บาท/ล.';
      case 'free_product':
        return freeProductLabel(subtotal: subtotal);
    }
    return name;
  }

  String? promotionNoteLine({double? subtotal}) {
    if (isFreeProduct) {
      final label = freeProductLabel(subtotal: subtotal);
      if (label.isEmpty) return null;
      return 'โปรแถม: $label';
    }
    return 'โปร: $name (${benefitSummary()})';
  }

  factory Promotion.fromMap(Map<String, Object?> m) => Promotion(
        id: m['id'] as int,
        name: m['name'] as String,
        description: m['description'] as String?,
        type: m['type'] as String,
        value: (m['value'] as num).toDouble(),
        minAmount: (m['min_amount'] as num).toDouble(),
        fuelTypeId: m['fuel_type_id'] as int?,
        startsAt: (m['starts_at'] as String?) != null
            ? DateTime.parse(m['starts_at'] as String)
            : null,
        endsAt: (m['ends_at'] as String?) != null
            ? DateTime.parse(m['ends_at'] as String)
            : null,
        isActive: (m['is_active'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        rewardProductId: m['reward_product_id'] as int?,
        rewardQty: (m['reward_qty'] as num?)?.toInt() ?? 1,
        rewardProductName: m['reward_product_name'] as String?,
        rewardProductPrice: (m['reward_product_price'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'value': value,
        'min_amount': minAmount,
        'fuel_type_id': fuelTypeId,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'reward_product_id': rewardProductId,
        'reward_qty': rewardQty,
      };
}

class Discount {
  final int id;
  final String name;
  final String type; // percent | fixed
  final double value;
  final bool isActive;

  Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.isActive = true,
  });

  double applyTo(double subtotal) => type == 'percent'
      ? (subtotal * value / 100).clamp(0, subtotal)
      : value.clamp(0, subtotal);

  factory Discount.fromMap(Map<String, Object?> m) => Discount(
        id: m['id'] as int,
        name: m['name'] as String,
        type: m['type'] as String,
        value: (m['value'] as num).toDouble(),
        isActive: (m['is_active'] as int) == 1,
      );
}
