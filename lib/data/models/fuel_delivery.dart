/// Grouped deliveries submitted together (same batch_key).
class FuelImportBatch {
  static const statusPending = 'pending';
  static const statusReceived = 'received';

  final String batchKey;
  final int supplierId;
  final String supplierName;
  final String? supplierSnapshot;
  final DateTime createdAt;
  final String? orderNote;
  final double? shippingCost;
  final String status;
  final List<FuelDeliveryLine> lines;

  const FuelImportBatch({
    required this.batchKey,
    required this.supplierId,
    required this.supplierName,
    this.supplierSnapshot,
    required this.createdAt,
    this.orderNote,
    this.shippingCost,
    required this.status,
    required this.lines,
  });

  bool get isPending => status == statusPending;
  bool get isReceived => status == statusReceived;

  double get totalOrderedLiters =>
      lines.fold(0.0, (sum, line) => sum + line.orderedLiters);

  double get totalReceivedLiters => lines.fold(
        0.0,
        (sum, line) => sum + (line.receivedLiters ?? 0),
      );

  int get lineCount => lines.length;

  double? get totalPurchaseCost {
    var total = 0.0;
    var hasCost = false;
    for (final line in lines) {
      final cost = line.unitCost;
      if (cost != null) {
        hasCost = true;
        final qty = line.receivedLiters ?? line.orderedLiters;
        total += cost * qty;
      }
    }
    return hasCost ? total : null;
  }
}

class FuelDeliveryLine {
  final int id;
  final int tankId;
  final int fuelTypeId;
  final String tankName;
  final String? fuelName;
  final double orderedLiters;
  final double? receivedLiters;
  final double? unitCost;
  final String status;

  const FuelDeliveryLine({
    required this.id,
    required this.tankId,
    required this.fuelTypeId,
    required this.tankName,
    this.fuelName,
    required this.orderedLiters,
    this.receivedLiters,
    this.unitCost,
    required this.status,
  });

  double get liters => orderedLiters;

  bool get isPending => status == FuelImportBatch.statusPending;
}

class FuelDelivery {
  final int id;
  final String batchKey;
  final int supplierId;
  final String supplierName;
  final int tankId;
  final int fuelTypeId;
  final String tankName;
  final String? fuelName;
  final double liters;
  final double? receivedLiters;
  final double? unitCost;
  final double? shippingCost;
  final String? note;
  final String? supplierSnapshot;
  final String? username;
  final String status;
  final DateTime createdAt;

  const FuelDelivery({
    required this.id,
    required this.batchKey,
    required this.supplierId,
    required this.supplierName,
    required this.tankId,
    required this.fuelTypeId,
    required this.tankName,
    this.fuelName,
    required this.liters,
    this.receivedLiters,
    this.unitCost,
    this.shippingCost,
    this.note,
    this.supplierSnapshot,
    this.username,
    required this.status,
    required this.createdAt,
  });

  FuelDeliveryLine get asLine => FuelDeliveryLine(
        id: id,
        tankId: tankId,
        fuelTypeId: fuelTypeId,
        tankName: tankName,
        fuelName: fuelName,
        orderedLiters: liters,
        receivedLiters: receivedLiters,
        unitCost: unitCost,
        status: status,
      );

  factory FuelDelivery.fromMap(Map<String, dynamic> map) {
    return FuelDelivery(
      id: map['id'] as int,
      batchKey: map['batch_key'] as String? ?? '',
      supplierId: map['supplier_id'] as int,
      supplierName: map['supplier_name'] as String? ?? '',
      tankId: map['tank_id'] as int,
      fuelTypeId: map['fuel_type_id'] as int? ?? 0,
      tankName: map['tank_name'] as String? ?? '',
      fuelName: map['fuel_name'] as String?,
      liters: (map['liters'] as num).toDouble(),
      receivedLiters: (map['received_liters'] as num?)?.toDouble(),
      unitCost: (map['unit_cost'] as num?)?.toDouble(),
      shippingCost: (map['shipping_cost'] as num?)?.toDouble(),
      note: map['note'] as String?,
      supplierSnapshot: map['supplier_snapshot'] as String?,
      username: map['username'] as String?,
      status: map['status'] as String? ?? FuelImportBatch.statusReceived,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
