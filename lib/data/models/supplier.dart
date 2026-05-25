import 'dart:convert';

/// ซัพพลายเออร์ — ข้อมูลสำหรับเอกสารรับน้ำมัน / ใบกำกับภาษี
class Supplier {
  static const typeCompany = 'company';
  static const typeIndividual = 'individual';

  final int? id;
  final String name;
  final String? company;
  final String? phone;
  final String? taxId;
  final String? branchNo;
  final String? address;
  final String? postalCode;
  final String? email;
  final String? contactName;
  final String? note;
  final String supplierType;
  final bool isActive;
  final DateTime? createdAt;

  const Supplier({
    this.id,
    required this.name,
    this.company,
    this.phone,
    this.taxId,
    this.branchNo,
    this.address,
    this.postalCode,
    this.email,
    this.contactName,
    this.note,
    this.supplierType = typeCompany,
    this.isActive = true,
    this.createdAt,
  });

  bool get isCompany => supplierType == typeCompany;

  /// ชื่อที่ใช้บนเอกสาร
  String get documentName {
    if (isCompany && company != null && company!.trim().isNotEmpty) {
      return company!.trim();
    }
    return name.trim();
  }

  String get displayLabel {
    final tax = taxId?.trim();
    if (tax != null && tax.isNotEmpty) {
      return '$documentName ($tax)';
    }
    return documentName;
  }

  String get typeLabel => isCompany ? 'นิติบุคคล' : 'บุคคลธรรมดา';

  bool get hasTaxDocumentData {
    final tax = taxId?.trim();
    return tax != null && tax.isNotEmpty;
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      company: map['company'] as String?,
      phone: map['phone'] as String?,
      taxId: map['tax_id'] as String?,
      branchNo: map['branch_no'] as String?,
      address: map['address'] as String?,
      postalCode: map['postal_code'] as String?,
      email: map['email'] as String?,
      contactName: map['contact_name'] as String?,
      note: map['note'] as String?,
      supplierType: map['supplier_type'] as String? ?? typeCompany,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'company': company,
      'phone': phone,
      'tax_id': taxId,
      'branch_no': branchNo ?? '00000',
      'address': address,
      'postal_code': postalCode,
      'email': email,
      'contact_name': contactName,
      'note': note,
      'supplier_type': supplierType,
      'is_active': isActive ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonMap() => {
        if (id != null) 'id': id,
        'name': name,
        'company': company,
        'phone': phone,
        'tax_id': taxId,
        'branch_no': branchNo,
        'address': address,
        'postal_code': postalCode,
        'email': email,
        'contact_name': contactName,
        'note': note,
        'supplier_type': supplierType,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory Supplier.fromJsonMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        company: m['company'] as String?,
        phone: m['phone'] as String?,
        taxId: m['tax_id'] as String?,
        branchNo: m['branch_no'] as String?,
        address: m['address'] as String?,
        postalCode: m['postal_code'] as String?,
        email: m['email'] as String?,
        contactName: m['contact_name'] as String?,
        note: m['note'] as String?,
        supplierType: m['supplier_type'] as String? ?? typeCompany,
        isActive: m['is_active'] as bool? ?? true,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
      );

  String encodeSnapshot() => jsonEncode(toJsonMap());

  factory Supplier.fromSnapshot(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) return Supplier.fromJsonMap(m);
    } catch (_) {}
    return const Supplier(name: '');
  }

  /// ข้อความสำหรับพิมพ์เอกสารรับน้ำมัน / ใบกำกับ
  String formatDocumentLines() {
    final lines = <String>['ผู้ขาย: $documentName'];
    final tax = taxId?.trim();
    if (tax != null && tax.isNotEmpty) {
      lines.add('เลขผู้เสียภาษี: $tax');
      final branch = branchNo?.trim();
      if (branch != null && branch.isNotEmpty) {
        lines.add('สาขา: $branch');
      }
    }
    final addr = address?.trim();
    if (addr != null && addr.isNotEmpty) {
      lines.add('ที่อยู่: $addr');
    }
    final zip = postalCode?.trim();
    if (zip != null && zip.isNotEmpty) lines.add('รหัสไปรษณีย์: $zip');
    final ph = phone?.trim();
    if (ph != null && ph.isNotEmpty) lines.add('โทร: $ph');
    final em = email?.trim();
    if (em != null && em.isNotEmpty) lines.add('อีเมล: $em');
    final contact = contactName?.trim();
    if (contact != null && contact.isNotEmpty) {
      lines.add('ผู้ติดต่อ: $contact');
    }
    return lines.join('\n');
  }
}
