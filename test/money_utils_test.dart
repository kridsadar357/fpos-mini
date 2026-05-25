import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/utils/money_utils.dart';

void main() {
  group('MoneyUtils', () {
    test('ceilBaht rounds up fractional baht', () {
      expect(MoneyUtils.ceilBaht(337.01), 338);
      expect(MoneyUtils.ceilBaht(337.99), 338);
      expect(MoneyUtils.ceilBaht(337.0), 337);
      expect(MoneyUtils.ceilBaht(0), 0);
    });

    test('fuelSubtotalFromLiters ceils liters × price', () {
      expect(
        MoneyUtils.fuelSubtotalFromLiters(liters: 10, pricePerLiter: 33.31),
        334,
      );
      expect(
        MoneyUtils.fuelSubtotalFromLiters(liters: 20, pricePerLiter: 35.5),
        710,
      );
    });

    test('payableTotal returns whole baht after discounts', () {
      expect(
        MoneyUtils.payableTotal(
          subtotal: 337.12,
          promotionAmount: 33.8,
          discountAmount: 0,
        ),
        305,
      );
      expect(
        MoneyUtils.payableTotal(
          subtotal: 500,
          promotionAmount: 50.5,
          discountAmount: 10.2,
        ),
        440,
      );
    });

    test('isWholeBaht detects satang', () {
      expect(MoneyUtils.isWholeBaht(100), isTrue);
      expect(MoneyUtils.isWholeBaht(100.5), isFalse);
    });
  });
}
