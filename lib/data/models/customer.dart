/// ลูกค้า — ข้อมูลสำหรับออกใบกำกับภาษีและขาย POS
class Customer {
  static const typeCompany = 'company';
  static const typeIndividual = 'individual';

  final int? id;
  final String name;
  final String? phone;
  final String? fleetCardNo;
  final String? company;
  final String? taxId;
  final String? branchNo;
  final String? address;
  final String? postalCode;
  final String? email;
  final String? contactName;
  final String customerType;
  final String? vehiclePlate;
  final String? note;
  final bool isActive;
  final DateTime createdAt;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.fleetCardNo,
    this.company,
    this.taxId,
    this.branchNo,
    this.address,
    this.postalCode,
    this.email,
    this.contactName,
    this.customerType = typeCompany,
    this.vehiclePlate,
    this.note,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isCompany => customerType == typeCompany;

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? fleetCardNo,
    String? company,
    String? taxId,
    String? branchNo,
    String? address,
    String? postalCode,
    String? email,
    String? contactName,
    String? customerType,
    String? vehiclePlate,
    String? note,
    bool? isActive,
    DateTime? createdAt,
    bool clearVehiclePlate = false,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        fleetCardNo: fleetCardNo ?? this.fleetCardNo,
        company: company ?? this.company,
        taxId: taxId ?? this.taxId,
        branchNo: branchNo ?? this.branchNo,
        address: address ?? this.address,
        postalCode: postalCode ?? this.postalCode,
        email: email ?? this.email,
        contactName: contactName ?? this.contactName,
        customerType: customerType ?? this.customerType,
        vehiclePlate:
            clearVehiclePlate ? null : (vehiclePlate ?? this.vehiclePlate),
        note: note ?? this.note,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );

  /// ชื่อที่ใช้บนใบกำกับภาษี
  String get invoiceName {
    if (isCompany && company != null && company!.trim().isNotEmpty) {
      return company!.trim();
    }
    return name.trim();
  }

  String get displayLabel {
    final tax = taxId?.trim();
    if (tax != null && tax.isNotEmpty) {
      return '$invoiceName ($tax)';
    }
    return invoiceName;
  }

  String get typeLabel => isCompany ? 'นิติบุคคล' : 'บุคคลธรรมดา';

  factory Customer.legacyPlate(String plate) => Customer(
        name: plate,
        vehiclePlate: plate,
        customerType: typeIndividual,
        createdAt: DateTime.now(),
      );

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        fleetCardNo: m['fleet_card_no'] as String?,
        company: m['company'] as String?,
        taxId: m['tax_id'] as String?,
        branchNo: m['branch_no'] as String?,
        address: m['address'] as String?,
        postalCode: m['postal_code'] as String?,
        email: m['email'] as String?,
        contactName: m['contact_name'] as String?,
        customerType: m['customer_type'] as String? ?? typeCompany,
        vehiclePlate: m['vehicle_plate'] as String?,
        note: m['note'] as String?,
        isActive: (m['is_active'] as int?) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toDbMap({bool includeId = true}) {
    final m = <String, Object?>{
      'name': name,
      'phone': phone,
      'fleet_card_no': fleetCardNo,
      'company': company,
      'tax_id': taxId,
      'branch_no': branchNo ?? '00000',
      'address': address,
      'postal_code': postalCode,
      'email': email,
      'contact_name': contactName,
      'customer_type': customerType,
      'vehicle_plate': vehiclePlate,
      'note': note,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
    if (includeId && id != null) m['id'] = id;
    return m;
  }

  /// สำหรับพักบิล / serialize
  Map<String, dynamic> toJsonMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'fleet_card_no': fleetCardNo,
        'company': company,
        'tax_id': taxId,
        'branch_no': branchNo,
        'address': address,
        'postal_code': postalCode,
        'email': email,
        'contact_name': contactName,
        'customer_type': customerType,
        'vehicle_plate': vehiclePlate,
        'note': note,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  factory Customer.fromJsonMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        fleetCardNo: m['fleet_card_no'] as String?,
        company: m['company'] as String?,
        taxId: m['tax_id'] as String?,
        branchNo: m['branch_no'] as String?,
        address: m['address'] as String?,
        postalCode: m['postal_code'] as String?,
        email: m['email'] as String?,
        contactName: m['contact_name'] as String?,
        customerType: m['customer_type'] as String? ?? typeCompany,
        vehiclePlate: m['vehicle_plate'] as String?,
        note: m['note'] as String?,
        isActive: m['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  /// บันทึก snapshot ลง transaction.notes สำหรับใบกำกับ/พิมพ์ซ้ำ
  String formatTaxNotes() {
    final lines = <String>['ลูกค้า: $invoiceName'];
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
    if (contact != null && contact.isNotEmpty) lines.add('ผู้ติดต่อ: $contact');
    final plate = vehiclePlate?.trim();
    if (plate != null && plate.isNotEmpty) lines.add('ทะเบียนรถ: $plate');
    final card = fleetCardNo?.trim();
    if (card != null && card.isNotEmpty) lines.add('บัตรฟลีท: $card');
    return lines.join('\n');
  }

  bool get hasTaxInvoiceData {
    final tax = taxId?.trim();
    return tax != null && tax.isNotEmpty;
  }
}
