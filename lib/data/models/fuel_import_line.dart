/// One fuel line in a multi-item supplier purchase.
class FuelImportLine {
  final int tankId;
  final double liters;
  final double? unitCost;

  const FuelImportLine({
    required this.tankId,
    required this.liters,
    this.unitCost,
  });
}
