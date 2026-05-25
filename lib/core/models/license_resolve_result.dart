class LicenseGraceStatus {
  final bool active;
  final bool expired;
  final int graceDays;
  final DateTime? lastVerifiedAt;
  final DateTime? graceUntil;
  final int daysRemaining;

  const LicenseGraceStatus({
    this.active = false,
    this.expired = false,
    this.graceDays = 7,
    this.lastVerifiedAt,
    this.graceUntil,
    this.daysRemaining = 0,
  });

  String get displayMessage {
    if (active && graceUntil != null) {
      return 'Offline grace — ใช้งานได้ถึง '
          '${graceUntil!.day}/${graceUntil!.month}/${graceUntil!.year + 543} '
          '($daysRemaining วัน)';
    }
    if (expired) {
      return 'Grace หมดแล้ว — กรุณาเชื่อมต่ออินเทอร์เน็ตเพื่อยืนยัน License';
    }
    return '';
  }
}

class LicenseResolveResult {
  final String licenseType;
  final bool syncedOnline;
  final bool offlineGrace;
  final bool graceExpired;
  final String? message;
  final LicenseGraceStatus? grace;

  const LicenseResolveResult({
    required this.licenseType,
    this.syncedOnline = false,
    this.offlineGrace = false,
    this.graceExpired = false,
    this.message,
    this.grace,
  });
}
