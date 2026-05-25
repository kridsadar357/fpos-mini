import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fuel_color_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/dispenser.dart';
import '../../../data/repositories/dispenser_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';

class DispenserNozzleSettingsScreen extends StatefulWidget {
  const DispenserNozzleSettingsScreen({super.key});

  @override
  State<DispenserNozzleSettingsScreen> createState() =>
      _DispenserNozzleSettingsScreenState();
}

class _DispenserNozzleSettingsScreenState
    extends State<DispenserNozzleSettingsScreen> {
  final _repo = DispenserRepository();
  List<Dispenser> _dispensers = [];
  final Map<int, List<Map<String, dynamic>>> _nozzlesByDispenser = {};
  List<Map<String, Object?>> _tanks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dispensers = await _repo.listAll();
    final tanks = await _repo.listTanksForPicker();
    final nozzlesMap = <int, List<Map<String, dynamic>>>{};
    for (final d in dispensers) {
      if (d.id != null) {
        nozzlesMap[d.id!] = await _repo.getDetailedNozzles(d.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _dispensers = dispensers;
      _tanks = tanks;
      _nozzlesByDispenser
        ..clear()
        ..addAll(nozzlesMap);
      _loading = false;
    });
  }

  Future<void> _addDispenser() async {
    final ctrl = TextEditingController();
    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'เพิ่มตู้จ่ายน้ำมัน',
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'ชื่อตู้จ่าย (เช่น ตู้จ่าย 2)',
        ),
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'เพิ่ม',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) {
      if (mounted) ToastUtils.show(context, 'กรุณาระบุชื่อตู้จ่าย');
      return;
    }
    await _repo.createDispenser(name);
    await _load();
    if (mounted) ToastUtils.show(context, 'เพิ่มตู้จ่ายแล้ว');
  }

  Future<void> _renameDispenser(Dispenser d) async {
    final ctrl = TextEditingController(text: d.name);
    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'แก้ไขชื่อตู้จ่าย',
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'ชื่อตู้จ่าย'),
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true || d.id == null) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    await _repo.updateDispenser(d.id!, name: name);
    await _load();
  }

  Future<void> _confirmDeleteDispenser(Dispenser d) async {
    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'ลบตู้จ่าย',
      message: 'ลบ "${d.name}" และมือจ่ายทั้งหมดของตู้นี้?',
      icon: Icons.warning_amber_rounded,
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'ลบ',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true || d.id == null) return;
    await _repo.deleteDispenser(d.id!);
    await _load();
    if (mounted) ToastUtils.show(context, 'ลบตู้จ่ายแล้ว');
  }

  Future<void> _addNozzle(Dispenser d) async {
    if (d.id == null) return;
    if (_tanks.isEmpty) {
      ToastUtils.show(context, 'ยังไม่มีถังน้ำมัน — ตั้งค่าถังก่อน');
      return;
    }
    var tankId = _tanks.first['id'] as int;
    final existing = _nozzlesByDispenser[d.id!] ?? [];
    final defaultNumber = existing.isEmpty
        ? 1
        : (existing
                .map((n) => n['nozzle_number'] as int)
                .reduce((a, b) => a > b ? a : b) +
            1);
    final numberCtrl =
        TextEditingController(text: defaultNumber.toString());

    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'เพิ่มมือจ่าย — ${d.name}',
      content: StatefulBuilder(
        builder: (context, setLocal) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: tankId,
                decoration: const InputDecoration(labelText: 'ถังน้ำมัน'),
                items: _tanks
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as int,
                        child: Text(
                          '${t['name']} (${t['fuel_name']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => tankId = v ?? tankId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'หมายเลขมือจ่าย',
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'เพิ่ม',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true) return;
    final number = int.tryParse(numberCtrl.text) ?? defaultNumber;
    await _repo.createNozzle(
      dispenserId: d.id!,
      tankId: tankId,
      nozzleNumber: number,
    );
    await _load();
    if (mounted) ToastUtils.show(context, 'เพิ่มมือจ่ายแล้ว');
  }

  Future<void> _editNozzle(
    Dispenser d,
    Map<String, dynamic> nozzle,
  ) async {
    if (d.id == null || _tanks.isEmpty) return;
    var tankId = nozzle['tank_id'] as int;
    final nozzleId = nozzle['id'] as int;
    final numberCtrl = TextEditingController(
      text: '${nozzle['nozzle_number']}',
    );

    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'แก้ไขมือจ่าย #${nozzle['nozzle_number']}',
      content: StatefulBuilder(
        builder: (context, setLocal) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: tankId,
                decoration: const InputDecoration(labelText: 'ถังน้ำมัน'),
                items: _tanks
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as int,
                        child: Text('${t['name']} (${t['fuel_name']})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => tankId = v ?? tankId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'หมายเลขมือจ่าย',
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true) return;
    final number = int.tryParse(numberCtrl.text) ??
        (nozzle['nozzle_number'] as int);
    await _repo.updateNozzle(nozzleId, tankId: tankId, nozzleNumber: number);
    await _load();
  }

  Future<void> _deleteNozzle(Map<String, dynamic> nozzle) async {
    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'ลบมือจ่าย',
      message: 'ลบมือจ่าย #${nozzle['nozzle_number']}?',
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context),
        ),
        PrimaryButton(
          label: 'ลบ',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok != true) return;
    await _repo.deleteNozzle(nozzle['id'] as int);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final totalNozzles =
        _nozzlesByDispenser.values.fold(0, (sum, list) => sum + list.length);
    final activeCount = _dispensers.where((d) => d.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'ตู้จ่ายและมือจ่าย',
        subtitle: 'ตั้งค่าตู้จ่ายน้ำมันและมือจ่าย',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.white),
            onPressed: _addDispenser,
            tooltip: 'เพิ่มตู้จ่าย',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_dispensers.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: r.h(80)),
                        Icon(
                          Icons.local_gas_station_outlined,
                          size: r.sp(56),
                          color: AppColors.greyLight,
                        ),
                        SizedBox(height: r.h(12)),
                        Center(
                          child: Text(
                            'ยังไม่มีตู้จ่าย',
                            style: TextStyle(
                              fontSize: r.sp(14),
                              fontWeight: FontWeight.w800,
                              color: AppColors.greyDark,
                            ),
                          ),
                        ),
                        SizedBox(height: r.h(4)),
                        Center(
                          child: Text(
                            'กด + มุมขวาบนเพื่อเพิ่มตู้จ่ายแรก',
                            style: TextStyle(
                              color: AppColors.greyMedium,
                              fontSize: r.sp(11),
                            ),
                          ),
                        ),
                        SizedBox(height: r.h(16)),
                        Center(
                          child: PrimaryButton(
                            label: 'เพิ่มตู้จ่าย',
                            icon: Icons.add_rounded,
                            onPressed: _addDispenser,
                          ),
                        ),
                      ],
                    );
                  }

                  final wide = constraints.maxWidth >= 720;
                  final cols = wide ? 2 : 1;

                  return ListView(
                    padding: EdgeInsets.all(r.w(10)),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _SummaryBar(
                        r: r,
                        dispensers: _dispensers.length,
                        nozzles: totalNozzles,
                        active: activeCount,
                      ),
                      SizedBox(height: r.h(10)),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: r.h(8),
                          crossAxisSpacing: r.w(8),
                          childAspectRatio: wide ? 1.35 : 1.05,
                        ),
                        itemCount: _dispensers.length,
                        itemBuilder: (_, i) {
                          final d = _dispensers[i];
                          final nozzles = d.id != null
                              ? (_nozzlesByDispenser[d.id!] ?? [])
                              : <Map<String, dynamic>>[];
                          return _DispenserCard(
                            dispenser: d,
                            nozzles: nozzles,
                            onToggle: (v) async {
                              if (d.id == null) return;
                              await _repo.updateDispenser(d.id!, isActive: v);
                              await _load();
                            },
                            onRename: () => _renameDispenser(d),
                            onDelete: () => _confirmDeleteDispenser(d),
                            onAddNozzle: () => _addNozzle(d),
                            onEditNozzle: (n) => _editNozzle(d, n),
                            onDeleteNozzle: _deleteNozzle,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final Responsive r;
  final int dispensers;
  final int nozzles;
  final int active;

  const _SummaryBar({
    required this.r,
    required this.dispensers,
    required this.nozzles,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ตู้จ่าย', '$dispensers', AppColors.corporateBlue),
      ('มือจ่าย', '$nozzles', AppColors.fuelBenzene),
      ('เปิดใช้งาน', '$active', AppColors.success),
    ];

    return Row(
      children: items
          .map(
            (e) => Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: e.$1 == items.last.$1 ? 0 : r.w(6),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: r.w(10),
                  vertical: r.h(8),
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.greyLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.$1,
                      style: TextStyle(
                        fontSize: r.sp(9),
                        color: AppColors.greyMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      e.$2,
                      style: TextStyle(
                        fontSize: r.sp(16),
                        fontWeight: FontWeight.w900,
                        color: e.$3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DispenserCard extends StatelessWidget {
  final Dispenser dispenser;
  final List<Map<String, dynamic>> nozzles;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddNozzle;
  final void Function(Map<String, dynamic>) onEditNozzle;
  final void Function(Map<String, dynamic>) onDeleteNozzle;

  const _DispenserCard({
    required this.dispenser,
    required this.nozzles,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onAddNozzle,
    required this.onEditNozzle,
    required this.onDeleteNozzle,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final active = dispenser.isActive;
    final accent = active ? AppColors.corporateBlue : AppColors.greyMedium;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(r.w(10), r.h(8), r.w(4), r.h(8)),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accent, width: 4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: r.w(36),
                  height: r.w(36),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_gas_station_rounded,
                    color: accent,
                    size: r.sp(20),
                  ),
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispenser.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: r.sp(13),
                          color: AppColors.corporateBlueDark,
                          decoration:
                              active ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        '${nozzles.length} มือจ่าย',
                        style: TextStyle(
                          fontSize: r.sp(9),
                          color: AppColors.greyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.w(6),
                    vertical: r.h(2),
                  ),
                  decoration: BoxDecoration(
                    color: (active ? AppColors.success : AppColors.greyMedium)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    active ? 'เปิด' : 'ปิด',
                    style: TextStyle(
                      fontSize: r.sp(8),
                      fontWeight: FontWeight.w800,
                      color: active ? AppColors.success : AppColors.greyMedium,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.greyDark,
                    size: r.sp(20),
                  ),
                  onSelected: (v) {
                    switch (v) {
                      case 'toggle':
                        onToggle(!active);
                      case 'rename':
                        onRename();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(active ? 'ปิดใช้งาน' : 'เปิดใช้งาน'),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('แก้ไขชื่อ'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'ลบตู้จ่าย',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(r.w(10), 0, r.w(10), r.h(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: nozzles.isEmpty
                        ? Center(
                            child: Text(
                              'ยังไม่มีมือจ่าย',
                              style: TextStyle(
                                color: AppColors.greyMedium,
                                fontSize: r.sp(11),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: nozzles.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: r.h(4)),
                            itemBuilder: (_, i) {
                              final n = nozzles[i];
                              return _NozzleTile(
                                nozzle: n,
                                r: r,
                                onEdit: () => onEditNozzle(n),
                                onDelete: () => onDeleteNozzle(n),
                              );
                            },
                          ),
                  ),
                  SizedBox(
                    height: r.h(32),
                    child: OutlinedButton.icon(
                      onPressed: onAddNozzle,
                      icon: Icon(Icons.add_rounded, size: r.sp(14)),
                      label: Text(
                        'เพิ่มมือจ่าย',
                        style: TextStyle(
                          fontSize: r.sp(10),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.corporateBlue,
                        side: BorderSide(
                          color: AppColors.corporateBlue
                              .withValues(alpha: 0.35),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: r.w(8)),
                      ),
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

class _NozzleTile extends StatelessWidget {
  final Map<String, dynamic> nozzle;
  final Responsive r;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NozzleTile({
    required this.nozzle,
    required this.r,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fuelColor = fuelColorFromNozzle(nozzle);
    final fuelName = nozzle['fuel_name']?.toString() ?? '';
    final tankName = nozzle['tank_name']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(8),
        vertical: r.h(6),
      ),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(30),
            height: r.w(30),
            decoration: BoxDecoration(
              color: fuelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: fuelColor.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${nozzle['nozzle_number']}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: fuelColor,
                fontSize: r.sp(11),
              ),
            ),
          ),
          SizedBox(width: r.w(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortFuelLabel(fuelName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: r.sp(10),
                    color: fuelColor,
                  ),
                ),
                Text(
                  tankName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.sp(8),
                    color: AppColors.greyMedium,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(icon: Icons.edit_rounded, onTap: onEdit),
          _IconBtn(icon: Icons.close_rounded, onTap: onDelete, muted: true),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool muted;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 16,
          color: muted ? AppColors.greyMedium : AppColors.corporateBlue,
        ),
      ),
    );
  }
}
