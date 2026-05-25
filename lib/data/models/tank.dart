class Tank {
  final int? id;
  final String name;
  final int fuelTypeId;
  final double capacity;
  final double currentLiters;
  final String? fuelName;
  final String? colorHex;

  Tank({
    this.id,
    required this.name,
    required this.fuelTypeId,
    required this.capacity,
    required this.currentLiters,
    this.fuelName,
    this.colorHex,
  });

  factory Tank.fromMap(Map<String, dynamic> map) {
    return Tank(
      id: map['id'],
      name: map['name'],
      fuelTypeId: map['fuel_type_id'],
      capacity: map['capacity'].toDouble(),
      currentLiters: map['current_liters'].toDouble(),
      fuelName: map['fuel_name'] as String?,
      colorHex: map['color_hex'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'fuel_type_id': fuelTypeId,
      'capacity': capacity,
      'current_liters': currentLiters,
      if (fuelName != null) 'fuel_name': fuelName,
      if (colorHex != null) 'color_hex': colorHex,
    };
  }

  double get percentFull => (currentLiters / capacity).clamp(0.0, 1.0);

  /// ลิตรว่างที่รับเพิ่มได้
  double get availableLiters =>
      (capacity - currentLiters).clamp(0.0, capacity);

  bool canReceive(double liters) =>
      liters > 0 && currentLiters + liters <= capacity + 0.001;

  double overflowIfReceive(double liters) =>
      (currentLiters + liters - capacity).clamp(0.0, double.infinity);
}
