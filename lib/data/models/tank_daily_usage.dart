class TankDailyUsage {
  final DateTime day;
  final double soldLiters;
  final double receivedLiters;

  const TankDailyUsage({
    required this.day,
    this.soldLiters = 0,
    this.receivedLiters = 0,
  });

  double get netLiters => receivedLiters - soldLiters;
}
