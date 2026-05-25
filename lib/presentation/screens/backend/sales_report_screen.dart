import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/fuel_color_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/fuel_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _txRepo = TransactionRepository();
  int _days = 7;
  SalesPeriodSummary? _summary;
  Map<int, String> _fuelNames = {};
  bool _loading = true;
  _SaleFilter _filter = _SaleFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final to = DateTime.now();
    final from = DateTime(to.year, to.month, to.day)
        .subtract(Duration(days: _days - 1));
    final summary = await _txRepo.salesPeriodSummary(from: from, to: to);
    final fuels = await FuelRepository().listAll();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _fuelNames = {for (final f in fuels) f.id: f.name};
      _loading = false;
    });
  }

  List<Transaction> _filtered(SalesPeriodSummary s) {
    switch (_filter) {
      case _SaleFilter.fuel:
        return s.transactions.where((t) => t.isFuelSale).toList();
      case _SaleFilter.product:
        return s.transactions.where((t) => t.isProductSale).toList();
      case _SaleFilter.all:
        return s.transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final s = _summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'รายงานการขาย',
        subtitle: s == null
            ? 'กำลังโหลด…'
            : '${Fmt.displayDate(s.from)} – ${Fmt.displayDate(s.to)}',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final data = _summary!;
                final wide = constraints.maxWidth >= 760;
                final pad = r.w(8);
                final gap = r.h(6);

                return RefreshIndicator(
                  onRefresh: _load,
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<int>(
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: TextStyle(fontSize: r.sp(11)),
                                ),
                                segments: const [
                                  ButtonSegment(value: 1, label: Text('วันนี้')),
                                  ButtonSegment(value: 7, label: Text('7 วัน')),
                                  ButtonSegment(
                                      value: 30, label: Text('30 วัน')),
                                ],
                                selected: {_days},
                                onSelectionChanged: (v) {
                                  setState(() => _days = v.first);
                                  _load();
                                },
                              ),
                            ),
                            SizedBox(width: r.w(8)),
                            SegmentedButton<_SaleFilter>(
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                textStyle: TextStyle(fontSize: r.sp(10)),
                              ),
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: _SaleFilter.all,
                                  label: Text('ทั้งหมด'),
                                ),
                                ButtonSegment(
                                  value: _SaleFilter.fuel,
                                  label: Text('น้ำมัน'),
                                ),
                                ButtonSegment(
                                  value: _SaleFilter.product,
                                  label: Text('สินค้า'),
                                ),
                              ],
                              selected: {_filter},
                              onSelectionChanged: (v) =>
                                  setState(() => _filter = v.first),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        _CompactKpiBar(summary: data, r: r),
                        SizedBox(height: gap),
                        Expanded(
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _TxListPanel(
                                        transactions: _filtered(data),
                                        fuelNames: _fuelNames,
                                        r: r,
                                      ),
                                    ),
                                    SizedBox(width: r.w(8)),
                                    Expanded(
                                      flex: 4,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            _BreakdownCard(
                                              title: 'ช่องทางชำระ',
                                              icon: Icons.payments_rounded,
                                              color: AppColors.corporateBlue,
                                              entries: data.byPayment.entries
                                                  .map(
                                                    (e) => _BreakdownEntry(
                                                      Fmt.paymentMethod(e.key),
                                                      e.value,
                                                    ),
                                                  )
                                                  .toList(),
                                              r: r,
                                              compact: true,
                                            ),
                                            SizedBox(height: gap),
                                            _BreakdownCard(
                                              title: 'ยอดตามน้ำมัน',
                                              icon: Icons.local_gas_station_rounded,
                                              color: AppColors.fuel95,
                                              entries: data.byFuel.entries
                                                  .map(
                                                    (e) => _BreakdownEntry(
                                                      _fuelNames[e.key] ??
                                                          '#${e.key}',
                                                      e.value,
                                                      color: fuelColorForName(
                                                        _fuelNames[e.key] ?? '',
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              r: r,
                                              compact: true,
                                            ),
                                            if (data.byDay.length > 1) ...[
                                              SizedBox(height: gap),
                                              _DailyBreakdown(
                                                days: data.byDay,
                                                r: r,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  children: [
                                    _BreakdownCard(
                                      title: 'ช่องทางชำระ',
                                      icon: Icons.payments_rounded,
                                      color: AppColors.corporateBlue,
                                      entries: data.byPayment.entries
                                          .map(
                                            (e) => _BreakdownEntry(
                                              Fmt.paymentMethod(e.key),
                                              e.value,
                                            ),
                                          )
                                          .toList(),
                                      r: r,
                                      compact: true,
                                    ),
                                    SizedBox(height: gap),
                                    _BreakdownCard(
                                      title: 'ยอดตามน้ำมัน',
                                      icon: Icons.local_gas_station_rounded,
                                      color: AppColors.fuel95,
                                      entries: data.byFuel.entries
                                          .map(
                                            (e) => _BreakdownEntry(
                                              _fuelNames[e.key] ?? '#${e.key}',
                                              e.value,
                                              color: fuelColorForName(
                                                _fuelNames[e.key] ?? '',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      r: r,
                                      compact: true,
                                    ),
                                    SizedBox(height: gap),
                                    _TxListPanel(
                                      transactions: _filtered(data),
                                      fuelNames: _fuelNames,
                                      r: r,
                                      shrinkWrap: true,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CompactKpiBar extends StatelessWidget {
  final SalesPeriodSummary summary;
  final Responsive r;

  const _CompactKpiBar({required this.summary, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: r.h(48).clamp(42.0, 52.0),
      padding: EdgeInsets.symmetric(horizontal: r.w(8)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(r.r(8)),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        children: [
          _KpiCell('ยอดรวม', Fmt.money(summary.total), AppColors.corporateBlue, r),
          _divider(r),
          _KpiCell('น้ำมัน', Fmt.money(summary.fuelTotal), AppColors.fuel95, r),
          _divider(r),
          _KpiCell('สินค้า', Fmt.money(summary.productTotal), AppColors.fuel91, r),
          _divider(r),
          _KpiCell('รายการ', '${summary.count}', AppColors.info, r),
          _divider(r),
          _KpiCell('ลิตร', Fmt.liters(summary.liters), AppColors.corporateBlueDark, r),
        ],
      ),
    );
  }

  Widget _divider(Responsive r) => Container(
        width: 1,
        height: r.h(28),
        color: AppColors.greyLight,
        margin: EdgeInsets.symmetric(horizontal: r.w(4)),
      );
}

class _KpiCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Responsive r;

  const _KpiCell(this.label, this.value, this.color, this.r);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(8),
              color: AppColors.greyDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  final List<DailySalesBucket> days;
  final Responsive r;

  const _DailyBreakdown({required this.days, required this.r});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(10)),
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ยอดรายวัน',
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(4)),
          ...days.take(7).map(
                (d) => Padding(
                  padding: EdgeInsets.symmetric(vertical: r.h(2)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.displayDate(d.date),
                          style: TextStyle(fontSize: r.sp(10)),
                        ),
                      ),
                      Text(
                        '${d.count}',
                        style: TextStyle(
                          fontSize: r.sp(10),
                          color: AppColors.greyDark,
                        ),
                      ),
                      SizedBox(width: r.w(8)),
                      Text(
                        Fmt.money(d.total),
                        style: TextStyle(
                          fontSize: r.sp(10),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _TxListPanel extends StatelessWidget {
  final List<Transaction> transactions;
  final Map<int, String> fuelNames;
  final Responsive r;
  final bool shrinkWrap;

  const _TxListPanel({
    required this.transactions,
    required this.fuelNames,
    required this.r,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = transactions.isEmpty
        ? Center(
            child: Text(
              'ไม่มีรายการ',
              style: TextStyle(color: AppColors.greyMedium, fontSize: r.sp(12)),
            ),
          )
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            itemCount: transactions.length.clamp(0, 100),
            separatorBuilder: (_, __) => SizedBox(height: r.h(4)),
            itemBuilder: (context, i) {
              final t = transactions[i];
              return _TxRow(
                tx: t,
                fuelName: fuelNames[t.fuelTypeId] ?? 'น้ำมัน',
                r: r,
              );
            },
          );

    return GlassCard(
      padding: EdgeInsets.all(r.w(8)),
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'รายการขาย (${transactions.length})',
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(4)),
          if (shrinkWrap)
            content
          else
            Expanded(child: content),
        ],
      ),
    );
  }
}

enum _SaleFilter { all, fuel, product }

class _BreakdownEntry {
  final String label;
  final double value;
  final Color? color;

  _BreakdownEntry(this.label, this.value, {this.color});
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_BreakdownEntry> entries;
  final Responsive r;
  final bool compact;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
    required this.r,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    final pad = compact ? r.w(10) : r.w(14);
    return GlassCard(
      padding: EdgeInsets.all(pad),
      borderRadius: compact ? 8 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: r.sp(compact ? 16 : 20)),
              SizedBox(width: r.w(4)),
              Text(
                title,
                style: TextStyle(
                  fontSize: r.sp(compact ? 11 : 14),
                  fontWeight: FontWeight.w800,
                  color: AppColors.corporateBlueDark,
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(compact ? 6 : 10)),
          if (entries.isEmpty)
            Text(
              'ไม่มีข้อมูล',
              style: TextStyle(
                color: AppColors.greyMedium,
                fontSize: r.sp(compact ? 10 : 12),
              ),
            )
          else
            ...entries.map((e) {
              final pct = total > 0 ? e.value / total : 0.0;
              final barColor = e.color ?? color;
              return Padding(
                padding: EdgeInsets.only(bottom: r.h(compact ? 5 : 8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: r.sp(compact ? 10 : 12)),
                          ),
                        ),
                        Text(
                          Fmt.money(e.value),
                          style: TextStyle(
                            fontSize: r.sp(compact ? 10 : 12),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.h(3)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: compact ? 4 : 6,
                        backgroundColor: AppColors.greyLight,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final String fuelName;
  final Responsive r;

  const _TxRow({
    required this.tx,
    required this.fuelName,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final isFuel = tx.isFuelSale;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(8),
        vertical: r.h(5),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(r.r(6)),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        children: [
          Icon(
            isFuel ? Icons.local_gas_station : Icons.shopping_bag,
            size: r.sp(14),
            color: isFuel ? AppColors.fuel95 : AppColors.fuel91,
          ),
          SizedBox(width: r.w(6)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.displayTitle(fuelName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.sp(10),
                    color: AppColors.corporateBlueDark,
                  ),
                ),
                Text(
                  '${tx.receiptNo} · ${Fmt.paymentMethod(tx.paymentMethod)} · ${Fmt.receiptDate(tx.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sp(9),
                    color: AppColors.greyDark,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.money(tx.total),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: r.sp(11),
              color: AppColors.corporateBlue,
            ),
          ),
        ],
      ),
    );
  }
}
