import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/constants/app_constants.dart';
import 'package:fuel_pos/core/utils/money_utils.dart';
import 'package:fuel_pos/data/models/fuel_type.dart';
import 'package:fuel_pos/presentation/providers/app_state.dart';

void main() {
  group('AppState fuel money rounding', () {
    late AppState state;
    late FuelType fuel;

    setUp(() {
      state = AppState();
      fuel = FuelType(
        id: 1,
        code: 'DSL',
        name: 'ดีเซล B7',
        pricePerLiter: 31.94,
        colorHex: '#1E3D59',
      );
      state.selectFuel(fuel);
    });

    test('liter mode ceils subtotal to whole baht', () {
      state.toggleInputMode(true);
      state.appendInput('1');
      state.appendInput('0');

      expect(state.liters, 10);
      expect(state.subtotal, 320);
      expect(state.total, 320);
      expect(MoneyUtils.isWholeBaht(state.total), isTrue);
    });

    test('baht mode ceils entered amount', () {
      state.toggleInputMode(false);
      state.setQuickBaht(333.5);

      expect(state.subtotal, 334);
      expect(MoneyUtils.isWholeBaht(state.total), isTrue);
    });

    test('change is whole baht for cash payment', () {
      state.toggleInputMode(true);
      state.appendInput('1');
      state.appendInput('0');
      state.setPaymentMethod(PaymentMethod.cash);
      state.setReceivedAmount(500);

      expect(state.total, 320);
      expect(state.change, 180);
      expect(MoneyUtils.isWholeBaht(state.change), isTrue);
    });
  });
}
