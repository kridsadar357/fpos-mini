import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../widgets/glass_card.dart';

class DashboardDailySummaryScreen extends StatefulWidget {
  const DashboardDailySummaryScreen({super.key});

  @override
  State<DashboardDailySummaryScreen> createState() =>
      _DashboardDailySummaryScreenState();
}

class _DashboardDailySummaryScreenState
    extends State<DashboardDailySummaryScreen> {
  DailySummary? _summary;
  Map<int, String> _fuelNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await TransactionRepository().dailySummary(DateTime.now());
    final fuels = await FuelRepository().listAll();
    setState(() {
      _summary = summary;
      _fuelNames = {for (final f in fuels) f.id: f.name};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final s = _summary;

    return Padding(
      padding: EdgeInsets.all(r.w(16)),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : GlassCard(
              padding: EdgeInsets.all(r.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สรุปยอดวันนี้',
                      style: TextStyle(
                          fontSize: r.sp(20),
                          fontWeight: FontWeight.w900,
                          color: AppColors.corporateBlueDark)),
                  const Divider(),
                  _stat('จำนวนรายการ', '${s?.count ?? 0} รายการ'),
                  _stat('ยอดขายรวม', Fmt.money(s?.total ?? 0)),
                  _stat('ยอดขายน้ำมัน', Fmt.money(s?.fuelTotal ?? 0)),
                  _stat('ยอดขายสินค้า', Fmt.money(s?.productTotal ?? 0)),
                  _stat(
                    'รายการน้ำมัน / สินค้า',
                    '${s?.fuelCount ?? 0} / ${s?.productCount ?? 0}',
                  ),
                  _stat('ปริมาณน้ำมัน', Fmt.liters(s?.liters ?? 0)),
                  const SizedBox(height: 16),
                  Text('แยกตามช่องทางชำระ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: r.sp(14))),
                  const SizedBox(height: 8),
                  ...(s?.byPayment.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key),
                                Text(Fmt.money(e.value),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )) ??
                      []),
                  const SizedBox(height: 12),
                  Text('แยกตามน้ำมัน',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: r.sp(14))),
                  ...(s?.byFuel.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fuelNames[e.key] ?? 'น้ำมัน #${e.key}'),
                                Text(Fmt.money(e.value)),
                              ],
                            ),
                          )) ??
                      []),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('รีเฟรช'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.greyDark)),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      );
}
