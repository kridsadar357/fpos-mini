import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'FUEL POS';
  static const String appVersion = '1.0.0';
  static const String currencySymbol = '฿'; // swap for your locale (\$ / € / ¥)
  static const String currencyCode = 'THB';
  static const int decimalPlaces = 2;

  static const int sessionTimeoutMinutes = 30;
  static const int maxBackupAgeDays = 90;
  /// แจ้งเตือนถ้าไม่ได้สำรองในเครื่องเกินจำนวนวันนี้
  static const int backupWarnDays = 3;

  /// Cloud backup API (Pro+ license key as Bearer token)
  static const String cloudBackupEndpoint =
      'https://ttmb-tech.com/license/backup';

  // Default demo accounts — override in production via SQL seed
  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'admin123';
  static const String defaultCashierUsername = 'cashier';
  static const String defaultCashierPassword = 'cashier123';
}

enum UserRole { admin, cashier }

enum PaymentMethod { cash, transfer, qrCode, creditCard }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'เงินสด';
      case PaymentMethod.transfer:
        return 'โอนเงิน';
      case PaymentMethod.qrCode:
        return 'QR Code';
      case PaymentMethod.creditCard:
        return 'บัตรเครดิต';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return Icons.payments_rounded;
      case PaymentMethod.transfer:
        return Icons.account_balance_rounded;
      case PaymentMethod.qrCode:
        return Icons.qr_code_2_rounded;
      case PaymentMethod.creditCard:
        return Icons.credit_card_rounded;
    }
  }

  String get code {
    switch (this) {
      case PaymentMethod.cash: return 'CASH';
      case PaymentMethod.transfer: return 'TRANSFER';
      case PaymentMethod.qrCode: return 'QR';
      case PaymentMethod.creditCard: return 'CARD';
    }
  }

  bool get requiresChange => this == PaymentMethod.cash;
}
