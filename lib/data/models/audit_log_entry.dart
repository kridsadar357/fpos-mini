class AuditLogEntry {
  final int id;
  final int? userId;
  final String? username;
  final String action;
  final String? details;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    this.userId,
    this.username,
    required this.action,
    this.details,
    required this.createdAt,
  });

  factory AuditLogEntry.fromMap(Map<String, Object?> m) => AuditLogEntry(
        id: m['id'] as int,
        userId: m['user_id'] as int?,
        username: m['username'] as String?,
        action: m['action'] as String,
        details: m['details'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  String get actionLabel {
    switch (action) {
      case 'login':
        return 'เข้าสู่ระบบ';
      case 'logout':
        return 'ออกจากระบบ';
      case 'sale':
        return 'ขาย';
      case 'print':
        return 'พิมพ์';
      case 'product_sale':
        return 'ขายสินค้า';
      case 'fuel_import':
        return 'นำเข้าน้ำมัน';
      case 'backup':
        return 'สำรองข้อมูล';
      case 'restore':
        return 'กู้คืนข้อมูล';
      case 'settings':
        return 'ตั้งค่าระบบ';
      case 'shift_open':
        return 'เปิดกะ';
      case 'shift_close':
        return 'ปิดกะ';
      default:
        return action;
    }
  }
}
