import 'shift.dart';

class ShiftSummary {
  final Shift shift;
  final int saleCount;
  final double totalSales;
  final double fuelTotal;
  final double productTotal;
  final double liters;
  final int fuelCount;
  final int productCount;
  final Map<String, double> byPayment;
  final double cashSalesTotal;

  const ShiftSummary({
    required this.shift,
    required this.saleCount,
    required this.totalSales,
    required this.fuelTotal,
    required this.productTotal,
    required this.liters,
    required this.fuelCount,
    required this.productCount,
    required this.byPayment,
    required this.cashSalesTotal,
  });

  double get expectedDrawerCash => shift.openingCash + cashSalesTotal;
}
