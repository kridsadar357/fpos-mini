/// License tiers and per-module access rules.
enum LicenseTier {
  free,
  standard,
  pro,
  enterprise,
}

enum AppFeature {
  /// ขายสินค้าทั่วไป (POS sidebar)
  productSales,

  /// นำเข้าน้ำมัน (backend)
  fuelImport,

  /// คลังน้ำมันแบบเต็ม — กราฟ + ประวัติรับจาก fuel_deliveries
  fuelInventoryHistory,

  /// ปรับยอดถัง manual (ไม่บันทึกประวัติรับ)
  fuelInventoryManual,

  /// จัดการสินค้า
  productManagement,

  /// คลังสินค้า / รายงานสต็อก
  productStock,

  /// สำรองข้อมูล cloud
  cloudBackup,

  /// โปรโมชั่น
  promotions,
}

class LicenseFeatures {
  LicenseFeatures._();

  static LicenseTier tierFrom(String type) {
    switch (type.toLowerCase().trim()) {
      case 'enterprise':
        return LicenseTier.enterprise;
      case 'pro':
        return LicenseTier.pro;
      case 'standard':
        return LicenseTier.standard;
      default:
        return LicenseTier.free;
    }
  }

  static String tierLabel(LicenseTier tier) {
    switch (tier) {
      case LicenseTier.enterprise:
        return 'Enterprise';
      case LicenseTier.pro:
        return 'Pro';
      case LicenseTier.standard:
        return 'Standard';
      case LicenseTier.free:
        return 'Free';
    }
  }

  static bool isEnabled(LicenseTier tier, AppFeature feature) {
    switch (feature) {
      case AppFeature.productSales:
        return tier == LicenseTier.enterprise;

      case AppFeature.fuelImport:
        return tier == LicenseTier.pro || tier == LicenseTier.enterprise;

      case AppFeature.fuelInventoryHistory:
        return tier == LicenseTier.pro || tier == LicenseTier.enterprise;

      case AppFeature.fuelInventoryManual:
        return tier == LicenseTier.standard ||
            tier == LicenseTier.pro ||
            tier == LicenseTier.enterprise;

      case AppFeature.productManagement:
        return tier == LicenseTier.enterprise;

      case AppFeature.productStock:
        return tier == LicenseTier.enterprise;

      case AppFeature.cloudBackup:
        return tier == LicenseTier.pro || tier == LicenseTier.enterprise;

      case AppFeature.promotions:
        return tier == LicenseTier.pro || tier == LicenseTier.enterprise;
    }
  }

  /// แสดงเมนูคลังน้ำมัน (manual หรือ full)
  static bool showFuelInventoryMenu(LicenseTier tier) =>
      isEnabled(tier, AppFeature.fuelInventoryManual) ||
      isEnabled(tier, AppFeature.fuelInventoryHistory);
}
