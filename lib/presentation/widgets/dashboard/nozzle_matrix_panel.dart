import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/fuel_color_util.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/dispenser.dart';
import '../../providers/app_state.dart';
import '../glass_card.dart';

/// เลือกตู้จ่าย → มือจ่าย บนหน้าขายน้ำมัน
class NozzleMatrixPanel extends StatefulWidget {
  final List<Dispenser> dispensers;
  final Dispenser? selectedDispenser;
  final List<Map<String, dynamic>> nozzles;
  final Map<int, int> nozzleCounts;
  final void Function(Dispenser) onSelectDispenser;
  final void Function(Map<String, dynamic>) onSelectNozzle;

  const NozzleMatrixPanel({
    super.key,
    required this.dispensers,
    required this.selectedDispenser,
    required this.nozzles,
    this.nozzleCounts = const {},
    required this.onSelectDispenser,
    required this.onSelectNozzle,
  });

  @override
  State<NozzleMatrixPanel> createState() => _NozzleMatrixPanelState();
}

class _NozzleMatrixPanelState extends State<NozzleMatrixPanel> {
  int _step = 0;

  bool get _multiDispenser => widget.dispensers.length > 1;

  void _syncStep() {
    if (!_multiDispenser) {
      _step = 1;
    } else if (widget.selectedDispenser != null) {
      _step = 1;
    } else {
      _step = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncStep();
  }

  @override
  void didUpdateWidget(NozzleMatrixPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_multiDispenser) {
      _step = 1;
    } else if (widget.selectedDispenser == null) {
      _step = 0;
    }
  }

  void _goToNozzleStep() {
    if (mounted) setState(() => _step = 1);
  }

  void _goToDispenserStep() {
    if (mounted) setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final selectedId = state.selectedNozzle?['id'];

    return GlassCard(
      padding: EdgeInsets.all(r.w(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WizardStepBar(
            step: _step,
            showDispenserStep: _multiDispenser,
          ),
          SizedBox(height: r.h(6)),
          Expanded(
            child: _step == 0 && _multiDispenser
                ? _DispenserStep(
                    dispensers: widget.dispensers,
                    selected: widget.selectedDispenser,
                    nozzleCounts: widget.nozzleCounts,
                    onSelect: (d) {
                      widget.onSelectDispenser(d);
                      _goToNozzleStep();
                    },
                  )
                : _NozzleStep(
                    dispenser: widget.selectedDispenser,
                    nozzles: widget.nozzles,
                    selectedId: selectedId,
                    showBack: _multiDispenser,
                    onBack: _goToDispenserStep,
                    onSelect: widget.onSelectNozzle,
                  ),
          ),
        ],
      ),
    );
  }
}

class _WizardStepBar extends StatelessWidget {
  final int step;
  final bool showDispenserStep;

  const _WizardStepBar({
    required this.step,
    required this.showDispenserStep,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    if (!showDispenserStep) {
      return Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.corporateBlue,
            ),
            child: const Icon(Icons.water_drop_rounded,
                size: 16, color: AppColors.white),
          ),
          SizedBox(width: r.w(8)),
          Text(
            'เลือกมือจ่าย',
            style: TextStyle(
              color: AppColors.corporateBlueDark,
              fontSize: r.sp(12),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    Widget stepNode({
      required int number,
      required String label,
      required bool active,
      required bool done,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || done
                  ? AppColors.corporateBlue
                  : AppColors.greyLight,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.corporateBlue.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: done && !active
                ? const Icon(Icons.check_rounded,
                    size: 15, color: AppColors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: r.sp(11),
                      fontWeight: FontWeight.w900,
                      color: active
                          ? AppColors.white
                          : AppColors.greyMedium,
                    ),
                  ),
          ),
          SizedBox(width: r.w(6)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active
                  ? AppColors.corporateBlueDark
                  : AppColors.greyMedium,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        stepNode(
          number: 1,
          label: 'ตู้จ่าย',
          active: step == 0,
          done: step > 0,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: EdgeInsets.symmetric(horizontal: r.w(8)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.corporateBlue.withValues(alpha: 0.35),
                  step > 0
                      ? AppColors.corporateBlue
                      : AppColors.greyLight,
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        stepNode(
          number: 2,
          label: 'มือจ่าย',
          active: step == 1,
          done: false,
        ),
      ],
    );
  }
}

class _DispenserStep extends StatelessWidget {
  final List<Dispenser> dispensers;
  final Dispenser? selected;
  final Map<int, int> nozzleCounts;
  final void Function(Dispenser) onSelect;

  const _DispenserStep({
    required this.dispensers,
    required this.selected,
    required this.nozzleCounts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    if (dispensers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_gas_station_outlined,
                size: 36, color: AppColors.greyMedium.withValues(alpha: 0.6)),
            SizedBox(height: r.h(6)),
            Text(
              'ตั้งค่าตู้จ่ายในหลังบ้าน',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.greyMedium, fontSize: r.sp(11)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.touch_app_outlined,
                size: 15, color: AppColors.corporateBlue),
            SizedBox(width: r.w(6)),
            Expanded(
              child: Text(
                'แตะตู้จ่ายเพื่อไปขั้นถัดไป',
                style: TextStyle(
                  color: AppColors.greyMedium,
                  fontSize: r.sp(10),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.h(8)),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: r.h(8),
              crossAxisSpacing: r.w(8),
              childAspectRatio: 1.35,
            ),
            itemCount: dispensers.length,
            itemBuilder: (context, i) {
              final d = dispensers[i];
              return _DispenserCard(
                dispenser: d,
                selected: d.id == selected?.id,
                nozzleCount: d.id != null ? nozzleCounts[d.id!] ?? 0 : 0,
                onTap: () => onSelect(d),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DispenserCard extends StatelessWidget {
  final Dispenser dispenser;
  final bool selected;
  final int nozzleCount;
  final VoidCallback onTap;

  const _DispenserCard({
    required this.dispenser,
    required this.selected,
    required this.nozzleCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final active = selected;

    return Material(
      color: active ? AppColors.corporateBlue : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.corporateBlue : AppColors.greyLight,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.corporateBlue.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.corporateBlue.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.all(r.w(8)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.white.withValues(alpha: 0.15)
                            : AppColors.corporateBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_gas_station_rounded,
                        size: 20,
                        color: active ? AppColors.white : AppColors.corporateBlue,
                      ),
                    ),
                    const Spacer(),
                    if (nozzleCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.white.withValues(alpha: 0.15)
                              : AppColors.softWhite,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: active
                                ? AppColors.white.withValues(alpha: 0.3)
                                : AppColors.greyLight,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.water_drop_outlined,
                              size: 11,
                              color: active
                                  ? AppColors.white
                                  : AppColors.corporateBlue,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$nozzleCount',
                              style: TextStyle(
                                fontSize: r.sp(9),
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? AppColors.white
                                    : AppColors.corporateBlueDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Text(
                  dispenser.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.w900,
                    color: active
                        ? AppColors.white
                        : AppColors.corporateBlueDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'เลือกมือจ่าย',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.white.withValues(alpha: 0.85)
                            : AppColors.greyMedium,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: active
                          ? AppColors.white.withValues(alpha: 0.85)
                          : AppColors.corporateBlue,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NozzleStep extends StatelessWidget {
  final Dispenser? dispenser;
  final List<Map<String, dynamic>> nozzles;
  final int? selectedId;
  final bool showBack;
  final VoidCallback onBack;
  final void Function(Map<String, dynamic>) onSelect;

  const _NozzleStep({
    required this.dispenser,
    required this.nozzles,
    required this.selectedId,
    required this.showBack,
    required this.onBack,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final title = dispenser?.name ?? 'ตู้จ่าย';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showBack)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.corporateBlueDark),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                tooltip: 'เปลี่ยนตู้จ่าย',
              ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.corporateBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.local_gas_station_rounded,
                  size: 18, color: AppColors.corporateBlue),
            ),
            SizedBox(width: r.w(8)),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.corporateBlueDark,
                  fontSize: r.sp(13),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (nozzles.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(10), vertical: r.h(4)),
                decoration: BoxDecoration(
                  color: AppColors.corporateBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 14, color: AppColors.corporateBlue),
                    SizedBox(width: r.w(4)),
                    Text(
                      '${nozzles.length} หัว',
                      style: TextStyle(
                        color: AppColors.corporateBlue,
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: r.h(8)),
        if (nozzles.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop_outlined,
                      size: 36,
                      color: AppColors.greyMedium.withValues(alpha: 0.6)),
                  SizedBox(height: r.h(6)),
                  Text(
                    'ยังไม่มีมือจ่าย',
                    style: TextStyle(
                      color: AppColors.greyMedium,
                      fontSize: r.sp(10),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: r.h(8),
                crossAxisSpacing: r.w(8),
                childAspectRatio: 1.05,
              ),
              itemCount: nozzles.length,
              itemBuilder: (context, i) {
                final n = nozzles[i];
                return _NozzleCell(
                  nozzle: n,
                  selected: selectedId == n['id'],
                  onTap: () => onSelect(n),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _NozzleCell extends StatelessWidget {
  final Map<String, dynamic> nozzle;
  final bool selected;
  final VoidCallback onTap;

  const _NozzleCell({
    required this.nozzle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final fuelName = nozzle['fuel_name']?.toString() ?? '';
    final tankName = nozzle['tank_name']?.toString() ?? '';
    final color = fuelColorFromNozzle(nozzle);
    final number = nozzle['nozzle_number']?.toString() ?? '?';
    final short = shortFuelLabel(fuelName);

    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : AppColors.greyLight,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.25 : 0.1),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: r.sp(18),
                  ),
                ),
              ),
              SizedBox(height: r.h(6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    short,
                    style: TextStyle(
                      color: AppColors.corporateBlueDark,
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (tankName.isNotEmpty) ...[
                SizedBox(height: r.h(3)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.w(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.propane_tank_outlined,
                          size: 11, color: AppColors.greyMedium),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          tankName,
                          style: TextStyle(
                            fontSize: r.sp(8),
                            color: AppColors.greyMedium,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (selected) ...[
                SizedBox(height: r.h(4)),
                Icon(Icons.check_circle_rounded, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
