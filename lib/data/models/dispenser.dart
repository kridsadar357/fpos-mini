class Dispenser {
  final int? id;
  final String name;
  final bool isActive;

  Dispenser({
    this.id,
    required this.name,
    this.isActive = true,
  });

  factory Dispenser.fromMap(Map<String, dynamic> map) {
    return Dispenser(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }
}

class Nozzle {
  final int? id;
  final int dispenserId;
  final int tankId;
  final int nozzleNumber; // Physical nozzle number 1, 2, 3...

  Nozzle({
    this.id,
    required this.dispenserId,
    required this.tankId,
    required this.nozzleNumber,
  });

  factory Nozzle.fromMap(Map<String, dynamic> map) {
    return Nozzle(
      id: map['id'],
      dispenserId: map['dispenser_id'],
      tankId: map['tank_id'],
      nozzleNumber: map['nozzle_number'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dispenser_id': dispenserId,
      'tank_id': tankId,
      'nozzle_number': nozzleNumber,
    };
  }
}
