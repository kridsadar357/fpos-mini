import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/fuel_color_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/fuel_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../widgets/charts/sankey_flow_chart.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';

class DailyOverviewScreen extends StatefulWidget {
  const DailyOverviewScreen({super.key});

  @override
  State<DailyOverviewScreen> createState() => _DailyOverviewScreenState();
}

enum _TxFilter { all, fuel, product }

class _DailyOverviewScreenState extends State<DailyOverviewScreen> {
  DateTime _selected = DateTime.now();
  DailySummary? _summary;
  Map<int, String> _fuelNames = {};
  bool _loading = true;
  _TxFilter _filter = _TxFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await TransactionRepository().dailySummary(_selected);
    final fuels = await FuelRepository().listAll();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _fuelNames = {for (final f in fuels) f.id: f.name};
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selected = picked);
      await _load();
    }
  }

  List<Transaction> _filteredTxs(DailySummary s) {
    switch (_filter) {
      case _TxFilter.fuel:
        return s.transactions.where((t) => t.isFuelSale).toList();
      case _TxFilter.product:
        return s.transactions.where((t) => t.isProductSale).toList();
      case _TxFilter.all:
        return s.transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'ภาพรวมรายวัน',
        subtitle: Fmt.displayDate(_selected),
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final pad = r.w(8);
                final cardH = constraints.maxHeight - r.h(12);
                final summary = _summary!;
                final sankey = _buildSankey(summary);

                return RefreshIndicator(
                  onRefresh: _load,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, r.h(6), pad, r.h(6)),
                    child: SizedBox(
                      height: cardH,
                      child: GlassCard(
                        padding: EdgeInsets.all(r.w(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _KpiGrid(summary: summary, r: r),
                            SizedBox(height: r.h(8)),
                            Expanded(
                              child: wide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: _ShiftGrid(
                                            shifts: summary.byShift,
                                            r: r,
                                          ),
                                        ),
                                        SizedBox(width: r.w(8)),
                                        Expanded(
                                          flex: 5,
                                          child: _ChartPanel(
                                            title: 'Sankey — กะ → ชนิด → ชำระ',
                                            r: r,
                                            child: SankeyFlowChart(
                                              nodes: sankey.$1,
                                              links: sankey.$2,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: r.w(8)),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            children: [
                                              if (summary
                                                  .byPayment.isNotEmpty)
                                                Expanded(
                                                  child: _ChartPanel(
                                                    title: 'ช่องทางชำระ',
                                                    r: r,
                                                    child: _PaymentBarChart(
                                                      byPayment:
                                                          summary.byPayment,
                                                    ),
                                                  ),
                                                ),
                                              if (summary.byFuel.isNotEmpty)
                                                SizedBox(height: r.h(8)),
                                              if (summary.byFuel.isNotEmpty)
                                                Expanded(
                                                  child: _FuelBreakdown(
                                                    byFuel: summary.byFuel,
                                                    fuelNames: _fuelNames,
                                                    r: r,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView(
                                      padding: EdgeInsets.zero,
                                      children: [
                                        SizedBox(
                                          height: r.h(180),
                                          child: _ShiftGrid(
                                            shifts: summary.byShift,
                                            r: r,
                                          ),
                                        ),
                                        SizedBox(height: r.h(8)),
                                        SizedBox(
                                          height: r.h(220),
                                          child: _ChartPanel(
                                            title: 'Sankey — กะ → ชนิด → ชำระ',
                                            r: r,
                                            child: SankeyFlowChart(
                                              nodes: sankey.$1,
                                              links: sankey.$2,
                                            ),
                                          ),
                                        ),
                                        if (summary.byPayment.isNotEmpty) ...[
                                          SizedBox(height: r.h(8)),
                                          SizedBox(
                                            height: r.h(160),
                                            child: _ChartPanel(
                                              title: 'ช่องทางชำระ',
                                              r: r,
                                              child: _PaymentBarChart(
                                                byPayment: summary.byPayment,
                                              ),
                                            ),
                                          ),
                                        ],
                                        SizedBox(height: r.h(8)),
                                        SizedBox(
                                          height: r.h(220),
                                          child: _TxListSection(
                                            summary: summary,
                                            filter: _filter,
                                            fuelNames: _fuelNames,
                                            filtered: _filteredTxs(summary),
                                            onFilterChanged: (f) =>
                                                setState(() => _filter = f),
                                            r: r,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            if (wide) ...[
                              SizedBox(height: r.h(8)),
                              SizedBox(
                                height: r.h(200),
                                child: _TxListSection(
                                  summary: summary,
                                  filter: _filter,
                                  fuelNames: _fuelNames,
                                  filtered: _filteredTxs(summary),
                                  onFilterChanged: (f) =>
                                      setState(() => _filter = f),
                                  r: r,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  (List<SankeyNode>, List<SankeyLink>) _buildSankey(DailySummary summary) {
    final nodes = <SankeyNode>[];
    final links = <SankeyLink>[];
    final nodeColors = <String, Color>{};

    void addNode({
      required String id,
      required String label,
      required int column,
      required double value,
      required Color color,
    }) {
      nodes.add(SankeyNode(
        id: id,
        label: label,
        column: column,
        value: value,
        color: color,
      ));
      nodeColors[id] = color;
    }

    for (var i = 0; i < summary.byShift.length; i++) {
      final sh = summary.byShift[i];
      addNode(
        id: 'shift_${sh.shiftId ?? 'none'}',
        label: sh.label(i),
        column: 0,
        value: sh.total,
        color: AppColors.corporateBlue,
      );
    }

    final catTotals = <String, double>{};
    for (final t in summary.transactions) {
      final cat = t.isProductSale ? 'product' : 'fuel_${t.fuelTypeId}';
      catTotals[cat] = (catTotals[cat] ?? 0) + t.total;
    }

    for (final e in catTotals.entries) {
      final color = e.key == 'product'
          ? AppColors.gold
          : fuelColorForName(
              _fuelNames[int.tryParse(e.key.replaceFirst('fuel_', '')) ?? 0] ??
                  '',
            );
      final label = e.key == 'product'
          ? 'สินค้า'
          : (_fuelNames[int.parse(e.key.replaceFirst('fuel_', ''))] ??
              'น้ำมัน');
      addNode(
        id: e.key,
        label: label,
        column: 1,
        value: e.value,
        color: color,
      );
    }

    for (final e in summary.byPayment.entries) {
      addNode(
        id: 'pay_${e.key}',
        label: paymentLabel(e.key),
        column: 2,
        value: e.value,
        color: AppColors.corporateBlueDark,
      );
    }

    final linkTotals = <String, double>{};
    for (final t in summary.transactions) {
      final shift = 'shift_${t.shiftId ?? 'none'}';
      final cat = t.isProductSale ? 'product' : 'fuel_${t.fuelTypeId}';
      final pay = 'pay_${t.paymentMethod}';
      linkTotals['$shift|$cat'] =
          (linkTotals['$shift|$cat'] ?? 0) + t.total;
      linkTotals['$cat|$pay'] = (linkTotals['$cat|$pay'] ?? 0) + t.total;
    }

    linkTotals.forEach((key, value) {
      if (value <= 0) return;
      final parts = key.split('|');
      if (parts.length != 2) return;
      links.add(SankeyLink(
        sourceId: parts[0],
        targetId: parts[1],
        value: value,
        color: nodeColors[parts[1]] ??
            nodeColors[parts[0]] ??
            AppColors.corporateBlue,
      ));
    });

    return (nodes, links);
  }
}

String paymentLabel(String code) => Fmt.paymentMethod(code);

class _KpiGrid extends StatelessWidget {
  final DailySummary summary;
  final Responsive r;

  const _KpiGrid({required this.summary, required this.r});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('รายได้รวม', Fmt.money(summary.total), AppColors.corporateBlueDark),
      ('น้ำมัน', Fmt.money(summary.fuelTotal), AppColors.fuel91),
      ('สินค้า', Fmt.money(summary.productTotal), AppColors.gold),
      ('ลิตร', Fmt.liters(summary.liters), AppColors.fuelBenzene),
      ('รายการน้ำมัน', '${summary.fuelCount}', AppColors.corporateBlue),
      ('รายการสินค้า', '${summary.productCount}', AppColors.corporateBlue),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 700 ? 6 : 3;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: r.h(6),
          crossAxisSpacing: r.w(6),
          childAspectRatio: cols >= 6 ? 2.4 : 2.1,
          children: items
              .map(
                (e) => Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.w(8),
                    vertical: r.h(6),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.greyLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        e.$1,
                        style: TextStyle(
                          fontSize: r.sp(9),
                          color: AppColors.greyMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e.$2,
                          style: TextStyle(
                            fontSize: r.sp(14),
                            fontWeight: FontWeight.w900,
                            color: e.$3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ShiftGrid extends StatelessWidget {
  final List<ShiftDaySummary> shifts;
  final Responsive r;

  const _ShiftGrid({required this.shifts, required this.r});

  @override
  Widget build(BuildContext context) {
    return _ChartPanel(
      title: 'ยอดขายแต่ละกะ (${shifts.length})',
      r: r,
      child: shifts.isEmpty
          ? Center(
              child: Text(
                'ไม่มีข้อมูลกะในวันนี้',
                style: TextStyle(
                  color: AppColors.greyMedium,
                  fontSize: r.sp(11),
                ),
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: shifts.length >= 3 ? 3 : shifts.length,
                mainAxisSpacing: r.h(6),
                crossAxisSpacing: r.w(6),
                childAspectRatio: 1.55,
              ),
              itemCount: shifts.length,
              itemBuilder: (context, i) {
                final sh = shifts[i];
                final open = sh.shift?.isOpen ?? false;
                return Container(
                  padding: EdgeInsets.all(r.w(8)),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: open
                          ? AppColors.success.withValues(alpha: 0.5)
                          : AppColors.greyLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sh.label(i),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: r.sp(10),
                                fontWeight: FontWeight.w800,
                                color: AppColors.corporateBlueDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.w(5),
                              vertical: r.h(1),
                            ),
                            decoration: BoxDecoration(
                              color: (open
                                      ? AppColors.success
                                      : AppColors.greyMedium)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sh.statusLabel,
                              style: TextStyle(
                                fontSize: r.sp(8),
                                fontWeight: FontWeight.w700,
                                color: open
                                    ? AppColors.success
                                    : AppColors.greyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        Fmt.money(sh.total),
                        style: TextStyle(
                          fontSize: r.sp(13),
                          fontWeight: FontWeight.w900,
                          color: AppColors.corporateBlue,
                        ),
                      ),
                      Text(
                        '${sh.count} รายการ · ${Fmt.liters(sh.liters)}',
                        style: TextStyle(
                          fontSize: r.sp(8),
                          color: AppColors.greyMedium,
                        ),
                      ),
                      if (sh.byPayment.isNotEmpty) ...[
                        SizedBox(height: r.h(4)),
                        Wrap(
                          spacing: r.w(4),
                          runSpacing: r.h(2),
                          children: sh.byPayment.entries.map((e) {
                            return Text(
                              '${paymentLabel(e.key)} ${Fmt.money(e.value)}',
                              style: TextStyle(
                                fontSize: r.sp(7),
                                color: AppColors.greyDark,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final String title;
  final Responsive r;
  final Widget child;

  const _ChartPanel({
    required this.title,
    required this.r,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greyLight),
      ),
      padding: EdgeInsets.all(r.w(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontSize: r.sp(11),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.h(6)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _FuelBreakdown extends StatelessWidget {
  final Map<int, double> byFuel;
  final Map<int, String> fuelNames;
  final Responsive r;

  const _FuelBreakdown({
    required this.byFuel,
    required this.fuelNames,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final max = byFuel.values.fold(0.0, (a, b) => a > b ? a : b);
    return _ChartPanel(
      title: 'น้ำมันแต่ละชนิด',
      r: r,
      child: ListView(
        padding: EdgeInsets.zero,
        children: byFuel.entries.map((e) {
          final name = fuelNames[e.key] ?? 'น้ำมัน ${e.key}';
          final pct = max == 0 ? 0.0 : (e.value / max).clamp(0, 1).toDouble();
          final color = fuelColorForName(name);
          return Padding(
            padding: EdgeInsets.only(bottom: r.h(4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: r.sp(9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.money(e.value),
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w800,
                        color: AppColors.corporateBlue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.h(2)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: AppColors.greyLight,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TxListSection extends StatelessWidget {
  final DailySummary summary;
  final _TxFilter filter;
  final Map<int, String> fuelNames;
  final List<Transaction> filtered;
  final ValueChanged<_TxFilter> onFilterChanged;
  final Responsive r;

  const _TxListSection({
    required this.summary,
    required this.filter,
    required this.fuelNames,
    required this.filtered,
    required this.onFilterChanged,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greyLight),
      ),
      padding: EdgeInsets.all(r.w(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'รายการขาย (${filtered.length})',
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SegmentedButton<_TxFilter>(
                segments: const [
                  ButtonSegment(value: _TxFilter.all, label: Text('ทั้งหมด')),
                  ButtonSegment(value: _TxFilter.fuel, label: Text('น้ำมัน')),
                  ButtonSegment(
                      value: _TxFilter.product, label: Text('สินค้า')),
                ],
                selected: {filter},
                onSelectionChanged: (s) => onFilterChanged(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(
                      fontSize: r.sp(9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(6)),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'ไม่มีรายการ',
                      style: TextStyle(
                        color: AppColors.greyMedium,
                        fontSize: r.sp(11),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length.clamp(0, 50),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.greyLight.withValues(alpha: 0.6),
                    ),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: r.h(4)),
                        child: Row(
                          children: [
                            _SaleTypeBadge(isProduct: t.isProductSale),
                            SizedBox(width: r.w(8)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.receiptNo,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.sp(10),
                                      color: AppColors.corporateBlue,
                                    ),
                                  ),
                                  Text(
                                    '${t.displayTitle(fuelNames[t.fuelTypeId] ?? '')} · ${paymentLabel(t.paymentMethod)} · ${Fmt.receiptDate(t.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: r.sp(9),
                                      color: AppColors.greyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Fmt.money(t.total),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: r.sp(12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleTypeBadge extends StatelessWidget {
  final bool isProduct;

  const _SaleTypeBadge({required this.isProduct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isProduct ? AppColors.gold : AppColors.corporateBlue)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isProduct ? 'สินค้า' : 'น้ำมัน',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isProduct ? AppColors.black : AppColors.corporateBlue,
        ),
      ),
    );
  }
}

class _PaymentBarChart extends StatelessWidget {
  final Map<String, double> byPayment;
  const _PaymentBarChart({required this.byPayment});

  @override
  Widget build(BuildContext context) {
    final entries = byPayment.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox();
    final max = entries.first.value;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: max * 1.15,
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                color: AppColors.corporateBlue,
                width: 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v >= 1000
                    ? '${(v / 1000).toStringAsFixed(1)}K'
                    : v.toInt().toString(),
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.greyMedium,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    paymentLabel(entries[idx].key),
                    style: const TextStyle(
                      color: AppColors.greyMedium,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.greyLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
