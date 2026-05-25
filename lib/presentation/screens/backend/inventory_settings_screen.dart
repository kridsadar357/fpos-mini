import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/license_features.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/fuel_color_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/tank.dart';
import '../../../data/models/tank_daily_usage.dart';
import '../../../data/repositories/tank_repository.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';

class InventorySettingsScreen extends StatefulWidget {
  const InventorySettingsScreen({super.key});

  @override
  State<InventorySettingsScreen> createState() =>
      _InventorySettingsScreenState();
}

class _InventorySettingsScreenState extends State<InventorySettingsScreen> {
  final _repo = TankRepository();
  List<Tank> _tanks = [];
  Map<int, List<TankDailyUsage>> _usageByTank = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tanks = await _repo.listAll();
    final showHistory = mounted &&
        context.read<AppState>().canUse(AppFeature.fuelInventoryHistory);
    final usage = <int, List<TankDailyUsage>>{};
    if (showHistory) {
      for (final tank in tanks) {
        final id = tank.id;
        if (id != null) {
          usage[id] = await _repo.dailyUsage(id, days: 7);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _tanks = tanks;
      _usageByTank = usage;
      _loading = false;
    });
  }

  Future<void> _manualAdjustTank(Tank tank) async {
    if (tank.id == null) return;
    final ctrl =
        TextEditingController(text: tank.currentLiters.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ปรับยอด ${tank.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'ลิตรคงเหลือ',
            helperText: 'ความจุ ${Fmt.liters(tank.capacity)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    if (result < 0 || result > tank.capacity + 0.001) {
      ToastUtils.show(
        context,
        'ยอดต้องอยู่ระหว่าง 0 – ${Fmt.liters(tank.capacity)}',
      );
      return;
    }
    try {
      await _repo.manualAdjustStock(
        tankId: tank.id!,
        newLiters: result,
        userId: context.read<AppState>().user?.id,
      );
    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, e.toString());
      return;
    }
    await _load();
    if (!mounted) return;
    ToastUtils.show(context, 'ปรับยอด ${tank.name} แล้ว');
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final showHistory = state.canUse(AppFeature.fuelInventoryHistory);
    final showManual = state.canUse(AppFeature.fuelInventoryManual);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'คลังน้ำมัน',
        subtitle: showHistory
            ? 'สต็อก + กราฟใช้/รับ 7 วันล่าสุด'
            : 'ปรับยอดถัง manual — ไม่เก็บประวัติรับ',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_tanks.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: r.h(48)),
                        Center(
                          child: Text(
                            'ยังไม่มีถังน้ำมัน',
                            style: TextStyle(
                              color: AppColors.greyMedium,
                              fontSize: r.sp(11),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final pad = r.w(8);
                  final gap = r.w(8);
                  final useSideBySide =
                      constraints.maxWidth >= 560 && _tanks.length <= 5;
                  final bodyH = constraints.maxHeight - pad * 2;

                  if (useSideBySide) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(pad),
                      children: [
                        SizedBox(
                          height: bodyH.clamp(260.0, constraints.maxHeight),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < _tanks.length; i++) ...[
                                if (i > 0) SizedBox(width: gap),
                                Expanded(
                                  child: _FuelTankMonitorCard(
                                    tank: _tanks[i],
                                    usage: _usageByTank[_tanks[i].id] ??
                                        const [],
                                    showHistory: showHistory,
                                    onManualAdjust: showManual
                                        ? () => _manualAdjustTank(_tanks[i])
                                        : null,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(pad),
                    itemCount: _tanks.length,
                    separatorBuilder: (_, __) => SizedBox(height: gap),
                    itemBuilder: (context, index) {
                      final tank = _tanks[index];
                      return SizedBox(
                        height: r.h(220),
                        child: _FuelTankMonitorCard(
                          tank: tank,
                          usage: _usageByTank[tank.id] ?? const [],
                          showHistory: showHistory,
                          onManualAdjust: showManual
                              ? () => _manualAdjustTank(tank)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _FuelTankMonitorCard extends StatelessWidget {
  final Tank tank;
  final List<TankDailyUsage> usage;
  final bool showHistory;
  final VoidCallback? onManualAdjust;

  const _FuelTankMonitorCard({
    required this.tank,
    required this.usage,
    this.showHistory = true,
    this.onManualAdjust,
  });

  String get _fuelLabel {
    final name = tank.fuelName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'ไม่ระบุชนิดน้ำมัน';
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pct = tank.capacity > 0
        ? (tank.currentLiters / tank.capacity).clamp(0.0, 1.0)
        : 0.0;
    var color = fuelColorForTank(
      colorHex: tank.colorHex,
      fuelName: tank.fuelName,
      tankName: tank.name,
    );
    final low = pct < 0.15;
    if (low) color = AppColors.danger;

    final totalSold =
        usage.fold<double>(0, (sum, row) => sum + row.soldLiters);
    final totalRecv =
        usage.fold<double>(0, (sum, row) => sum + row.receivedLiters);

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: r.r(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(10),
              vertical: r.h(6),
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(r.r(12)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.oil_barrel_rounded,
                    color: AppColors.white, size: r.sp(15)),
                SizedBox(width: r.w(6)),
                Expanded(
                  child: Text(
                    _fuelLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: r.sp(10),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  tank.name,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.9),
                    fontSize: r.sp(9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (low) ...[
                  SizedBox(width: r.w(6)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.w(4),
                      vertical: r.h(1),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'ต่ำ',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: r.sp(7),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(r.w(10), r.h(6), r.w(10), 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Fmt.liters(tank.currentLiters),
                        style: TextStyle(
                          fontSize: r.sp(16),
                          fontWeight: FontWeight.w900,
                          color: low
                              ? AppColors.danger
                              : AppColors.corporateBlueDark,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/ ${Fmt.liters(tank.capacity)} · ${(pct * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: r.sp(8),
                          color: AppColors.greyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: r.w(72),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: r.h(6),
                      backgroundColor: AppColors.greyLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showHistory)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  r.w(6),
                  r.h(4),
                  r.w(6),
                  r.h(4),
                ),
                child: _TankUsageChart(
                  usage: usage,
                  color: color,
                ),
              ),
            )
          else if (onManualAdjust != null)
            Padding(
              padding: EdgeInsets.fromLTRB(r.w(10), r.h(6), r.w(10), r.h(8)),
              child: Material(
                color: AppColors.corporateBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.r(8)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(r.r(8)),
                  onTap: onManualAdjust,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.w(10), vertical: r.h(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: r.sp(14), color: AppColors.corporateBlue),
                        SizedBox(width: r.w(6)),
                        Text(
                          'ปรับยอด manual',
                          style: TextStyle(
                            fontSize: r.sp(10),
                            fontWeight: FontWeight.w800,
                            color: AppColors.corporateBlueDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showHistory)
            Padding(
              padding: EdgeInsets.fromLTRB(r.w(10), 0, r.w(10), r.h(6)),
              child: Row(
                children: [
                  _LegendDot(color: color, label: 'ขาย'),
                  SizedBox(width: r.w(10)),
                  _LegendDot(
                    color: color.withValues(alpha: 0.35),
                    label: 'รับ',
                  ),
                  const Spacer(),
                  Text(
                    '7 วัน: ขาย ${Fmt.liters(totalSold)} · รับ ${Fmt.liters(totalRecv)}',
                    style: TextStyle(
                      fontSize: r.sp(7),
                      color: AppColors.greyDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: r.w(8),
          height: r.h(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.w(4)),
        Text(
          label,
          style: TextStyle(fontSize: r.sp(7), color: AppColors.greyDark),
        ),
      ],
    );
  }
}

class _TankUsageChart extends StatelessWidget {
  final List<TankDailyUsage> usage;
  final Color color;

  const _TankUsageChart({
    required this.usage,
    required this.color,
  });

  static const _weekdayTh = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    if (usage.isEmpty) {
      return Center(
        child: Text(
          'ไม่มีข้อมูล',
          style: TextStyle(fontSize: r.sp(9), color: AppColors.greyMedium),
        ),
      );
    }

    final maxVal = usage
        .map((u) => u.soldLiters > u.receivedLiters
            ? u.soldLiters
            : u.receivedLiters)
        .fold(0.0, (a, b) => a > b ? a : b);
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.25;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.greyLight.withValues(alpha: 0.8),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(usage.length, (i) {
          final row = usage[i];
          return BarChartGroupData(
            x: i,
            barsSpace: 2,
            barRods: [
              BarChartRodData(
                toY: row.soldLiters,
                color: color,
                width: r.w(7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
              BarChartRodData(
                toY: row.receivedLiters,
                color: color.withValues(alpha: 0.35),
                width: r.w(7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: maxVal > 0,
              reservedSize: r.w(28),
              getTitlesWidget: (value, _) {
                if (value <= 0 || value > maxY) return const SizedBox();
                if (value != (maxY / 2).roundToDouble() &&
                    value != maxY.roundToDouble()) {
                  return const SizedBox();
                }
                return Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toInt().toString(),
                  style: TextStyle(
                    fontSize: r.sp(7),
                    color: AppColors.greyMedium,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: r.h(16),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= usage.length) return const SizedBox();
                final day = usage[idx].day;
                return Padding(
                  padding: EdgeInsets.only(top: r.h(2)),
                  child: Text(
                    _weekdayTh[day.weekday - 1],
                    style: TextStyle(
                      fontSize: r.sp(7),
                      color: AppColors.greyMedium,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final row = usage[group.x];
              final isSold = rodIndex == 0;
              final label = isSold ? 'ขาย' : 'รับ';
              final liters = isSold ? row.soldLiters : row.receivedLiters;
              return BarTooltipItem(
                '$label\n${Fmt.liters(liters)}',
                TextStyle(
                  color: AppColors.white,
                  fontSize: r.sp(8),
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
