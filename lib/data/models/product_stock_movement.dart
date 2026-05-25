class ProductStockMovement {
  final int id;
  final int productId;
  final int qtyDelta;
  final int qtyAfter;
  final String movementType;
  final String? referenceType;
  final int? referenceId;
  final int? userId;
  final String? note;
  final DateTime createdAt;
  final String? productName;

  const ProductStockMovement({
    required this.id,
    required this.productId,
    required this.qtyDelta,
    required this.qtyAfter,
    required this.movementType,
    this.referenceType,
    this.referenceId,
    this.userId,
    this.note,
    required this.createdAt,
    this.productName,
  });

  bool get isInbound => qtyDelta > 0;

  String get typeLabel {
    switch (movementType) {
      case 'receive':
        return 'รับเข้า';
      case 'sale':
        return 'ขาย';
      case 'promo_reward':
        return 'แถมโปร';
      case 'adjustment':
        return 'ปรับยอด';
      default:
        return movementType;
    }
  }

  factory ProductStockMovement.fromMap(Map<String, Object?> m) =>
      ProductStockMovement(
        id: m['id'] as int,
        productId: m['product_id'] as int,
        qtyDelta: (m['qty_delta'] as num).toInt(),
        qtyAfter: (m['qty_after'] as num).toInt(),
        movementType: m['movement_type'] as String,
        referenceType: m['reference_type'] as String?,
        referenceId: m['reference_id'] as int?,
        userId: m['user_id'] as int?,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        productName: m['product_name'] as String?,
      );
}

class ProductStockSummary {
  final int productId;
  final String productName;
  final int currentQty;
  final int received;
  final int sold;
  final int promoGiven;
  final int adjusted;

  const ProductStockSummary({
    required this.productId,
    required this.productName,
    required this.currentQty,
    this.received = 0,
    this.sold = 0,
    this.promoGiven = 0,
    this.adjusted = 0,
  });
}
