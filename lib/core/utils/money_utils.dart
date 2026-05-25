/// Thai-baht helpers for POS — fuel sales use whole baht only (.00).
class MoneyUtils {
  MoneyUtils._();

  /// Round up to the next whole baht (no satang).
  static double ceilBaht(double amount) {
    if (amount <= 0) return 0;
    if (_isNearlyWholeBaht(amount)) return amount.roundToDouble();
    return amount.ceilToDouble();
  }

  static bool _isNearlyWholeBaht(double amount) =>
      (amount - amount.roundToDouble()).abs() < 1e-6;

  /// Round down to whole baht (used for discount lines).
  static double floorBaht(double amount) {
    if (amount <= 0) return 0;
    return amount.floorToDouble();
  }

  /// Fuel subtotal from liters × price — always ceiled to whole baht.
  static double fuelSubtotalFromLiters({
    required double liters,
    required double pricePerLiter,
  }) {
    if (liters <= 0 || pricePerLiter <= 0) return 0;
    return ceilBaht(liters * pricePerLiter);
  }

  /// Final payable amount after discounts — whole baht, never below zero.
  static double payableTotal({
    required double subtotal,
    double promotionAmount = 0,
    double discountAmount = 0,
  }) {
    final charge = ceilBaht(subtotal);
    final promo = floorBaht(promotionAmount);
    final discount = floorBaht(discountAmount);
    final raw = charge - promo - discount;
    return raw <= 0 ? 0 : ceilBaht(raw);
  }

  static bool isWholeBaht(double amount) => _isNearlyWholeBaht(amount);
}
