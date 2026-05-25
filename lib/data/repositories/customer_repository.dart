import '../../core/services/database_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  final _db = DatabaseService.instance;

  Future<List<Customer>> listActive() async {
    final rows = await _db.query(
      'customers',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getById(int id) async {
    final rows = await _db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<List<Customer>> search(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return listActive();
    final like = '%$q%';
    final rows = await _db.query(
      'customers',
      where: '''
        is_active = 1 AND (
          name LIKE ? OR company LIKE ? OR tax_id LIKE ? OR
          phone LIKE ? OR fleet_card_no LIKE ? OR vehicle_plate LIKE ?
        )
      ''',
      whereArgs: [like, like, like, like, like, like],
      orderBy: 'name ASC',
      limit: limit,
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> findByFleetCard(String cardNo) async {
    final rows = await _db.query(
      'customers',
      where: 'fleet_card_no = ? AND is_active = 1',
      whereArgs: [cardNo.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<int> create({
    required String name,
    String? phone,
    String? fleetCardNo,
    String? company,
    String? taxId,
    String? branchNo,
    String? address,
    String? postalCode,
    String? email,
    String? contactName,
    String customerType = Customer.typeCompany,
    String? vehiclePlate,
    String? note,
  }) async {
    return _db.insert('customers', {
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
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> update(Customer c) async {
    if (c.id == null) return;
    await _db.update(
      'customers',
      {
        'name': c.name,
        'phone': c.phone,
        'fleet_card_no': c.fleetCardNo,
        'company': c.company,
        'tax_id': c.taxId,
        'branch_no': c.branchNo ?? '00000',
        'address': c.address,
        'postal_code': c.postalCode,
        'email': c.email,
        'contact_name': c.contactName,
        'customer_type': c.customerType,
        'vehicle_plate': c.vehiclePlate,
        'note': c.note,
        'is_active': c.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }
}
