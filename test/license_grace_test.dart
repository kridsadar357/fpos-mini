import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_pos/core/services/license_service.dart';

void main() {
  group('LicenseService grace period', () {
    final verifiedAt = DateTime(2026, 5, 1, 12);

    test('isWithinGracePeriod returns true inside window', () {
      expect(
        LicenseService.isWithinGracePeriod(
          lastVerifiedAt: verifiedAt,
          now: DateTime(2026, 5, 5),
          graceDays: 7,
        ),
        isTrue,
      );
    });

    test('isWithinGracePeriod returns false after window', () {
      expect(
        LicenseService.isWithinGracePeriod(
          lastVerifiedAt: verifiedAt,
          now: DateTime(2026, 5, 10),
          graceDays: 7,
        ),
        isFalse,
      );
    });

    test('graceDaysRemaining counts down correctly', () {
      expect(
        LicenseService.graceDaysRemaining(
          lastVerifiedAt: verifiedAt,
          now: DateTime(2026, 5, 3),
          graceDays: 7,
        ),
        5,
      );
    });

    test('graceDaysRemaining is zero when expired', () {
      expect(
        LicenseService.graceDaysRemaining(
          lastVerifiedAt: verifiedAt,
          now: DateTime(2026, 5, 20),
          graceDays: 7,
        ),
        0,
      );
    });
  });
}
