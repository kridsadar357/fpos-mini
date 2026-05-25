enum SaleType { fuel, product }

class Transaction {
  static const saleTypeFuel = 'fuel';
  static const saleTypeProduct = 'product';

  final int id;
  final String receiptNo;
  final int cashierId;
  final int fuelTypeId;
  final String paymentMethod;
  final SaleType saleType;
  final int? productId;
  final double liters;
  final double pricePerLiter;
  final double subtotal;
  final int? promotionId;
  final double promotionAmount;
  final int? discountId;
  final double discountAmount;
  final double total;
  final double received;
  final double changeAmount;
  final bool printed;
  final int? customerId;
  final int? shiftId;
  final int? rewardProductId;
  final int rewardQty;
  final String? notes;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.receiptNo,
    required this.cashierId,
    required this.fuelTypeId,
    required this.paymentMethod,
    required this.liters,
    required this.pricePerLiter,
    required this.subtotal,
    this.promotionId,
    this.promotionAmount = 0,
    this.discountId,
    this.discountAmount = 0,
    required this.total,
    this.received = 0,
    this.changeAmount = 0,
    this.printed = false,
    this.customerId,
    this.shiftId,
    this.rewardProductId,
    this.rewardQty = 0,
    this.notes,
    this.saleType = SaleType.fuel,
    this.productId,
    required this.createdAt,
  });

  bool get isFuelSale => saleType == SaleType.fuel;
  bool get isProductSale => saleType == SaleType.product;

  String get saleTypeLabel => isProductSale ? 'สินค้าทั่วไป' : 'น้ำมัน';

  /// คำอธิบายสำหรับรายการย้อนหลัง
  String displayTitle(String fuelName) {
    if (isProductSale) {
      if (notes != null && notes!.startsWith('สินค้า:')) {
        final body = notes!.replaceFirst('สินค้า:', '').trim();
        final first = body.split('\n').first.trim();
        return first.isEmpty ? 'สินค้าทั่วไป' : first;
      }
      return 'สินค้าทั่วไป';
    }
    return fuelName;
  }

  static SaleType _saleTypeFromMap(Map<String, Object?> m) {
    final raw = m['sale_type'] as String?;
    if (raw == saleTypeProduct) return SaleType.product;
    if (raw == saleTypeFuel) return SaleType.fuel;
    if (m['product_id'] != null && (m['liters'] as num).toDouble() <= 0) {
      return SaleType.product;
    }
    final receipt = m['receipt_no'] as String? ?? '';
    if (receipt.startsWith('PD-')) return SaleType.product;
    return SaleType.fuel;
  }

  /// In-progress sale slip (not yet saved to DB).
  factory Transaction.draft({
    required int cashierId,
    required int fuelTypeId,
    required String paymentMethod,
    required double liters,
    required double pricePerLiter,
    required double subtotal,
    required double total,
    String? notes,
  }) {
    return Transaction(
      id: 0,
      receiptNo: 'DRAFT',
      cashierId: cashierId,
      fuelTypeId: fuelTypeId,
      paymentMethod: paymentMethod,
      liters: liters,
      pricePerLiter: pricePerLiter,
      subtotal: subtotal,
      total: total,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  factory Transaction.fromMap(Map<String, Object?> m) => Transaction(
        id: m['id'] as int,
        receiptNo: m['receipt_no'] as String,
        cashierId: m['cashier_id'] as int,
        fuelTypeId: m['fuel_type_id'] as int,
        paymentMethod: m['payment_method'] as String,
        liters: (m['liters'] as num).toDouble(),
        pricePerLiter: (m['price_per_liter'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
        promotionId: m['promotion_id'] as int?,
        promotionAmount: (m['promotion_amount'] as num).toDouble(),
        discountId: m['discount_id'] as int?,
        discountAmount: (m['discount_amount'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        received: (m['received'] as num).toDouble(),
        changeAmount: (m['change_amount'] as num).toDouble(),
        printed: (m['printed'] as int) == 1,
        customerId: m['customer_id'] as int?,
        shiftId: m['shift_id'] as int?,
        rewardProductId: m['reward_product_id'] as int?,
        rewardQty: (m['reward_qty'] as num?)?.toInt() ?? 0,
        notes: m['notes'] as String?,
        saleType: _saleTypeFromMap(m),
        productId: m['product_id'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'receipt_no': receiptNo,
        'cashier_id': cashierId,
        'fuel_type_id': fuelTypeId,
        'payment_method': paymentMethod,
        'liters': liters,
        'price_per_liter': pricePerLiter,
        'subtotal': subtotal,
        'promotion_id': promotionId,
        'promotion_amount': promotionAmount,
        'discount_id': discountId,
        'discount_amount': discountAmount,
        'total': total,
        'received': received,
        'change_amount': changeAmount,
        'printed': printed ? 1 : 0,
        'customer_id': customerId,
        'shift_id': shiftId,
        'reward_product_id': rewardProductId,
        'reward_qty': rewardQty,
        'notes': notes,
        'sale_type':
            saleType == SaleType.product ? saleTypeProduct : saleTypeFuel,
        'product_id': productId,
        'created_at': createdAt.toIso8601String(),
      };
}
