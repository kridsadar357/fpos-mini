import 'dart:convert';

/// Receipt block types that can be reordered on the designer screen.
enum ReceiptBlockType { logo, header, body, footer }

extension ReceiptBlockTypeX on ReceiptBlockType {
  String get id => name;

  String get label {
    switch (this) {
      case ReceiptBlockType.logo:
        return 'โลโก้';
      case ReceiptBlockType.header:
        return 'หัวใบเสร็จ';
      case ReceiptBlockType.body:
        return 'รายการขาย';
      case ReceiptBlockType.footer:
        return 'ท้ายใบเสร็จ';
    }
  }

  static ReceiptBlockType fromId(String id) =>
      ReceiptBlockType.values.firstWhere((e) => e.name == id);
}

class ReceiptTemplate {
  final List<ReceiptBlockType> blockOrder;
  final bool logoEnabled;
  final List<String> headerLines;
  final List<String> footerLines;

  const ReceiptTemplate({
    this.blockOrder = const [
      ReceiptBlockType.logo,
      ReceiptBlockType.header,
      ReceiptBlockType.body,
      ReceiptBlockType.footer,
    ],
    this.logoEnabled = true,
    this.headerLines = const [
      '{station_name}',
      '{station_address}',
      'เลขประจำตัวผู้เสียภาษี: {tax_id}',
    ],
    this.footerLines = const [
      '{receipt_footer}',
    ],
  });

  Map<String, dynamic> toJson() => {
        'blockOrder': blockOrder.map((b) => b.name).toList(),
        'logoEnabled': logoEnabled,
        'headerLines': headerLines,
        'footerLines': footerLines,
      };

  factory ReceiptTemplate.fromJson(Map<String, dynamic> json) {
    final orderRaw = json['blockOrder'] as List<dynamic>? ?? [];
    final order = orderRaw.isEmpty
        ? const ReceiptTemplate().blockOrder
        : orderRaw
            .map((e) => ReceiptBlockTypeX.fromId(e as String))
            .toList();

    // Ensure all blocks exist exactly once
    final complete = <ReceiptBlockType>[];
    for (final t in ReceiptBlockType.values) {
      if (order.contains(t)) complete.add(t);
    }
    for (final t in ReceiptBlockType.values) {
      if (!complete.contains(t)) complete.add(t);
    }

    return ReceiptTemplate(
      blockOrder: complete,
      logoEnabled: json['logoEnabled'] as bool? ?? true,
      headerLines: (json['headerLines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ReceiptTemplate().headerLines,
      footerLines: (json['footerLines'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ReceiptTemplate().footerLines,
    );
  }

  static ReceiptTemplate fromJsonString(String raw) {
    try {
      return ReceiptTemplate.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReceiptTemplate();
    }
  }

  String toJsonString() => jsonEncode(toJson());

  ReceiptTemplate copyWith({
    List<ReceiptBlockType>? blockOrder,
    bool? logoEnabled,
    List<String>? headerLines,
    List<String>? footerLines,
  }) =>
      ReceiptTemplate(
        blockOrder: blockOrder ?? this.blockOrder,
        logoEnabled: logoEnabled ?? this.logoEnabled,
        headerLines: headerLines ?? this.headerLines,
        footerLines: footerLines ?? this.footerLines,
      );
}

/// Placeholders for header/footer lines.
class ReceiptPlaceholders {
  static const help = '''
{station_name} — ชื่อสถานี
{station_address} — ที่อยู่
{tax_id} — เลขประจำตัวผู้เสียภาษี
{receipt_footer} — ข้อความท้าย (จากตั้งค่าทั่วไป)
{receipt_no} {date} {cashier} {plate} — ข้อมูลรายการ (ใช้ใน header ได้)
{customer_name} {customer_tax_id} {customer_branch} {customer_address} — ลูกค้า/ใบกำกับ''';

  static String apply(String line, Map<String, String> values) {
    var out = line;
    values.forEach((key, value) {
      out = out.replaceAll('{$key}', value);
    });
    return out;
  }
}
