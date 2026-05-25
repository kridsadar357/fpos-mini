class FuelImportProfitRow {
  final String fuelName;
  final int fuelTypeId;
  final double? previousUnitCost;
  final double? currentUnitCost;
  final double? shippingPerLiter;
  final double sellPricePerLiter;
  final double orderedLiters;

  const FuelImportProfitRow({
    required this.fuelName,
    required this.fuelTypeId,
    this.previousUnitCost,
    this.currentUnitCost,
    this.shippingPerLiter,
    required this.sellPricePerLiter,
    required this.orderedLiters,
  });

  double? get costChange {
    if (previousUnitCost == null || currentUnitCost == null) return null;
    return currentUnitCost! - previousUnitCost!;
  }

  double? get landedUnitCost {
    if (currentUnitCost == null) return null;
    return currentUnitCost! + (shippingPerLiter ?? 0);
  }

  double? get marginPerLiter {
    final landed = landedUnitCost;
    if (landed == null) return null;
    return sellPricePerLiter - landed;
  }

  double? get marginPercent {
    final m = marginPerLiter;
    if (m == null || sellPricePerLiter <= 0) return null;
    return (m / sellPricePerLiter) * 100;
  }

  double? get estimatedProfit {
    final m = marginPerLiter;
    if (m == null) return null;
    return m * orderedLiters;
  }
}
