import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/fuel_color_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/fuel_delivery.dart';
import '../../../data/models/fuel_import_profit.dart';
import '../../../data/models/tank.dart';
import '../../../data/repositories/fuel_delivery_repository.dart';
import '../../../data/repositories/tank_repository.dart';
import '../../../core/constants/license_features.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/license_gate.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import 'fuel_import_create_screen.dart';

class FuelImportScreen extends StatefulWidget {
  const FuelImportScreen({super.key});

  @override
  State<FuelImportScreen> createState() => _FuelImportScreenState();
}

class _FuelImportScreenState extends State<FuelImportScreen> {
  final _deliveryRepo = FuelDeliveryRepository();
  List<FuelImportBatch> _batches = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final batches = await _deliveryRepo.listAllBatches(limit: 100);
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FuelImportCreateScreen()),
    );
    if (created == true) await _load();
  }

  TextStyle _cellStyle(Responsive r, {FontWeight? weight}) => TextStyle(
        fontSize: r.sp(9),
        fontWeight: weight ?? FontWeight.w500,
      );

  TextStyle _headStyle(Responsive r) => TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: r.sp(9),
      );

  Widget _compactIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final r = Responsive.of(context);
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: r.w(26),
        minHeight: r.h(26),
      ),
      iconSize: r.sp(15),
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );
  }

  Widget _dialogCloseBtn(VoidCallback onTap) {
    final r = Responsive.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        minimumSize: Size(r.w(68), r.h(30)),
        padding: EdgeInsets.symmetric(horizontal: r.w(12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(
        'ปิด',
        style: TextStyle(
          fontSize: r.sp(10),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaCell(String label, String value, Responsive r) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: r.sp(8), color: AppColors.greyMedium)),
          Text(value,
              style: TextStyle(
                  fontSize: r.sp(9), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _batchMetaGrid(FuelImportBatch batch, Responsive r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metaCell('Supplier', batch.supplierName, r),
              _metaCell(
                  'สถานะ', batch.isPending ? 'รอรับ' : 'รับแล้ว', r),
            ],
          ),
        ),
        SizedBox(width: r.w(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metaCell('วันที่', Fmt.receiptDate(batch.createdAt), r),
              if (batch.shippingCost != null)
                _metaCell('ค่าขนส่ง', Fmt.money(batch.shippingCost!), r),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lineDetailRow(FuelDeliveryLine line, Responsive r) {
    final color = fuelColorForName(line.fuelName ?? line.tankName);
    final details = [
      'สั่ง ${Fmt.liters(line.orderedLiters)}',
      if (line.receivedLiters != null)
        'รับ ${Fmt.liters(line.receivedLiters!)}',
      if (line.unitCost != null) '${Fmt.money(line.unitCost!)}/ล.',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: r.h(3)),
      child: Row(
        children: [
          Container(width: 3, height: r.h(14), color: color),
          SizedBox(width: r.w(6)),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: line.fuelName ?? line.tankName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: r.sp(9),
                      color: AppColors.black,
                    ),
                  ),
                  TextSpan(
                    text: '  ·  $details',
                    style: TextStyle(
                      fontSize: r.sp(8),
                      color: AppColors.greyDark,
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

  Future<void> _showDetail(FuelImportBatch batch) async {
    final r = Responsive.of(context);
    await HighEndDialog.show<void>(
      context: context,
      compact: true,
      title: 'รายละเอียดใบสั่งซื้อ',
      icon: Icons.receipt_long_rounded,
      maxWidth: r.w(420),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _batchMetaGrid(batch, r),
          if (batch.orderNote != null && batch.orderNote!.isNotEmpty) ...[
            SizedBox(height: r.h(2)),
            _metaCell('หมายเหตุ', batch.orderNote!, r),
          ],
          Padding(
            padding: EdgeInsets.symmetric(vertical: r.h(4)),
            child: Divider(height: 1, color: AppColors.greyLight),
          ),
          Text(
            'รายการ (${batch.lineCount})',
            style: TextStyle(
              fontSize: r.sp(8),
              fontWeight: FontWeight.w800,
              color: AppColors.greyMedium,
            ),
          ),
          SizedBox(height: r.h(2)),
          ...batch.lines.map((line) => _lineDetailRow(line, r)),
        ],
      ),
      actions: [
        _dialogCloseBtn(() => Navigator.pop(context)),
      ],
    );
  }

  Future<void> _showReceipt(FuelImportBatch batch) async {
    if (batch.isReceived) {
      ToastUtils.show(context, 'ใบนี้รับเข้าแล้ว');
      return;
    }

    final received = await showDialog<Map<int, double>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReceiptConfirmDialog(batch: batch),
    );

    if (received == null || !mounted) return;

    try {
      await _deliveryRepo.confirmReceipt(
        batchKey: batch.batchKey,
        receivedByDeliveryId: received,
        userId: context.read<AppState>().user?.id,
      );
      if (!mounted) return;
      ToastUtils.show(context, 'บันทึกรับน้ำมันแล้ว');
      await _load();
    } catch (e) {
      if (mounted) ToastUtils.show(context, 'บันทึกรับไม่สำเร็จ: $e');
    }
  }

  Future<void> _showProfit(FuelImportBatch batch) async {
    final rows = await _deliveryRepo.computeProfit(batch.batchKey);
    if (!mounted) return;
    final r = Responsive.of(context);

    await HighEndDialog.show<void>(
      context: context,
      compact: true,
      title: 'ต้นทุน · กำไร',
      icon: Icons.trending_up_rounded,
      maxWidth: r.w(440),
      content: rows.isEmpty
          ? Text('ไม่มีข้อมูลต้นทุน',
              style: TextStyle(fontSize: r.sp(9)))
          : Column(
              children:
                  rows.map((row) => _ProfitRowCard(row: row, r: r)).toList(),
            ),
      actions: [
        _dialogCloseBtn(() => Navigator.pop(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LicenseGate(
      feature: AppFeature.fuelImport,
      title: 'นำเข้าน้ำมัน',
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'นำเข้าน้ำมัน',
        subtitle: 'รายการสั่งซื้อทั้งหมด',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.w(2)),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: r.w(8),
                  vertical: r.h(2),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _openCreate,
              icon: Icon(Icons.add_rounded,
                  color: AppColors.white, size: r.sp(16)),
              label: Text(
                'นำเข้าน้ำมัน',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: r.sp(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _batches.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: r.h(48)),
                            Center(
                              child: Text(
                                'ยังไม่มีรายการนำเข้า',
                                style: TextStyle(
                                  color: AppColors.greyMedium,
                                  fontSize: r.sp(11),
                                ),
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final tableWidth = constraints.maxWidth - r.w(16);
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                r.w(8),
                                r.h(6),
                                r.w(8),
                                r.h(8),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - r.h(14),
                                ),
                                child: GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: _ImportBatchTable(
                                    width: tableWidth,
                                    batches: _batches,
                                    r: r,
                                    headStyle: _headStyle(r),
                                    cellStyle: _cellStyle(r),
                                    onDetail: _showDetail,
                                    onReceipt: _showReceipt,
                                    onProfit: _showProfit,
                                    compactIcon: _compactIcon,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _ImportBatchTable extends StatelessWidget {
  final double width;
  final List<FuelImportBatch> batches;
  final Responsive r;
  final TextStyle headStyle;
  final TextStyle cellStyle;
  final Future<void> Function(FuelImportBatch) onDetail;
  final Future<void> Function(FuelImportBatch) onReceipt;
  final Future<void> Function(FuelImportBatch) onProfit;
  final Widget Function({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) compactIcon;

  const _ImportBatchTable({
    required this.width,
    required this.batches,
    required this.r,
    required this.headStyle,
    required this.cellStyle,
    required this.onDetail,
    required this.onReceipt,
    required this.onProfit,
    required this.compactIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableRow(
            r: r,
            headStyle: headStyle,
            isHeader: true,
            cells: [
              _CellSpec(flex: 2, child: Text('วันที่', style: headStyle)),
              _CellSpec(flex: 3, child: Text('Supplier', style: headStyle)),
              _CellSpec(
                  flex: 1,
                  align: TextAlign.center,
                  child: Text('ชนิด', style: headStyle)),
              _CellSpec(
                  flex: 2,
                  align: TextAlign.right,
                  child: Text('สั่ง', style: headStyle)),
              _CellSpec(
                  flex: 2,
                  align: TextAlign.right,
                  child: Text('รับ', style: headStyle)),
              _CellSpec(
                  flex: 2,
                  align: TextAlign.center,
                  child: Text('สถานะ', style: headStyle)),
              _CellSpec(
                  flex: 2,
                  align: TextAlign.center,
                  child: Text('จัดการ', style: headStyle)),
            ],
          ),
          ...batches.map((batch) => _TableRow(
                r: r,
                cellStyle: cellStyle,
                cells: [
                  _CellSpec(
                    flex: 2,
                    child: Text(
                      Fmt.receiptDate(batch.createdAt),
                      style: cellStyle,
                    ),
                  ),
                  _CellSpec(
                    flex: 3,
                    child: Text(
                      batch.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cellStyle,
                    ),
                  ),
                  _CellSpec(
                    flex: 1,
                    align: TextAlign.center,
                    child: Text('${batch.lineCount}', style: cellStyle),
                  ),
                  _CellSpec(
                    flex: 2,
                    align: TextAlign.right,
                    child: Text(
                      Fmt.liters(batch.totalOrderedLiters),
                      style: cellStyle,
                    ),
                  ),
                  _CellSpec(
                    flex: 2,
                    align: TextAlign.right,
                    child: Text(
                      batch.isReceived
                          ? Fmt.liters(batch.totalReceivedLiters)
                          : '-',
                      style: cellStyle,
                    ),
                  ),
                  _CellSpec(
                    flex: 2,
                    align: TextAlign.center,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.w(4),
                        vertical: r.h(1),
                      ),
                      decoration: BoxDecoration(
                        color: batch.isPending
                            ? AppColors.gold.withValues(alpha: 0.2)
                            : AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        batch.isPending ? 'รอรับ' : 'รับแล้ว',
                        style: TextStyle(
                          fontSize: r.sp(8),
                          fontWeight: FontWeight.w800,
                          color: batch.isPending
                              ? AppColors.greyDark
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  _CellSpec(
                    flex: 2,
                    align: TextAlign.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        compactIcon(
                          icon: Icons.visibility_outlined,
                          tooltip: 'ดูประวัติ',
                          onPressed: () => onDetail(batch),
                        ),
                        compactIcon(
                          icon: Icons.inventory_rounded,
                          tooltip: 'บันทึกรับ',
                          color: batch.isPending
                              ? AppColors.corporateBlue
                              : AppColors.greyLight,
                          onPressed:
                              batch.isPending ? () => onReceipt(batch) : null,
                        ),
                        compactIcon(
                          icon: Icons.trending_up_rounded,
                          tooltip: 'ต้นทุน/กำไร',
                          onPressed: () => onProfit(batch),
                        ),
                      ],
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }
}

class _CellSpec {
  final int flex;
  final Widget child;
  final TextAlign align;

  const _CellSpec({
    required this.flex,
    required this.child,
    this.align = TextAlign.left,
  });
}

class _TableRow extends StatelessWidget {
  final Responsive r;
  final List<_CellSpec> cells;
  final TextStyle? headStyle;
  final TextStyle? cellStyle;
  final bool isHeader;

  const _TableRow({
    required this.r,
    required this.cells,
    this.headStyle,
    this.cellStyle,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(8),
        vertical: r.h(isHeader ? 6 : 5),
      ),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.softWhite : null,
        border: Border(
          bottom: BorderSide(
            color: AppColors.greyLight.withValues(alpha: isHeader ? 1 : 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              flex: cell.flex,
              child: Align(
                alignment: _alignment(cell.align),
                child: cell.child,
              ),
            ),
        ],
      ),
    );
  }

  Alignment _alignment(TextAlign align) {
    switch (align) {
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }
}

class _ProfitRowCard extends StatelessWidget {
  final FuelImportProfitRow row;
  final Responsive r;

  const _ProfitRowCard({required this.row, required this.r});

  @override
  Widget build(BuildContext context) {
    final margin = row.marginPerLiter;
    final estimated = row.estimatedProfit;
    final marginColor = margin == null
        ? AppColors.greyDark
        : margin >= 0
            ? AppColors.success
            : AppColors.red;

    return Container(
      margin: EdgeInsets.only(bottom: r.h(3)),
      padding: EdgeInsets.symmetric(
        horizontal: r.w(8),
        vertical: r.h(5),
      ),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.fuelName,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: r.sp(9),
            ),
          ),
          SizedBox(height: r.h(2)),
          Text(
            'รอบก่อน ${row.previousUnitCost != null ? Fmt.money(row.previousUnitCost!) : '-'}'
            ' → รอบนี้ ${row.currentUnitCost != null ? Fmt.money(row.currentUnitCost!) : '-'}'
            '${row.costChange != null ? ' (${row.costChange! >= 0 ? '+' : ''}${Fmt.money(row.costChange!)})' : ''}',
            style: TextStyle(fontSize: r.sp(8), color: AppColors.greyDark),
          ),
          if (row.shippingPerLiter != null && row.shippingPerLiter! > 0)
            Text(
              'ขนส่ง/ล. ${Fmt.money(row.shippingPerLiter!)}'
              '${row.landedUnitCost != null ? ' · ต้นทุนรวม/ล. ${Fmt.money(row.landedUnitCost!)}' : ''}',
              style: TextStyle(fontSize: r.sp(8), color: AppColors.greyDark),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ขาย ${Fmt.money(row.sellPricePerLiter)}/ล.',
                  style:
                      TextStyle(fontSize: r.sp(8), color: AppColors.greyDark),
                ),
              ),
              if (margin != null)
                Text(
                  'กำไร/ล. ${Fmt.money(margin)} (${row.marginPercent?.toStringAsFixed(1) ?? '-'}%)',
                  style: TextStyle(
                    fontSize: r.sp(8),
                    fontWeight: FontWeight.w800,
                    color: marginColor,
                  ),
                ),
            ],
          ),
          if (estimated != null)
            Text(
              'รวม ${Fmt.liters(row.orderedLiters)} · ${Fmt.money(estimated)}',
              style: TextStyle(
                fontSize: r.sp(8),
                fontWeight: FontWeight.w800,
                color: marginColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptLineCalc {
  final FuelDeliveryLine line;
  final double receivedLiters;
  final Tank? tank;

  const _ReceiptLineCalc({
    required this.line,
    required this.receivedLiters,
    this.tank,
  });

  double get diffLiters => receivedLiters - line.orderedLiters;

  double? get availableLiters => tank?.availableLiters;

  double? get afterReceive =>
      tank != null ? tank!.currentLiters + receivedLiters : null;

  bool get exceedsCapacity =>
      tank != null && receivedLiters > 0 && !tank!.canReceive(receivedLiters);

  double get overflowLiters =>
      tank?.overflowIfReceive(receivedLiters) ?? 0;

  double? fuelCost(double? shippingShare) {
    if (line.unitCost == null) return null;
    return line.unitCost! * receivedLiters + (shippingShare ?? 0);
  }
}

class _ReceiptConfirmDialog extends StatefulWidget {
  final FuelImportBatch batch;

  const _ReceiptConfirmDialog({required this.batch});

  @override
  State<_ReceiptConfirmDialog> createState() => _ReceiptConfirmDialogState();
}

class _ReceiptConfirmDialogState extends State<_ReceiptConfirmDialog> {
  late final Map<int, TextEditingController> _ctrls;
  final _tankRepo = TankRepository();
  Map<int, Tank> _tanksById = {};
  bool _loadingTanks = true;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final line in widget.batch.lines)
        line.id: TextEditingController(
          text: line.orderedLiters.toStringAsFixed(2),
        ),
    };
    _loadTanks();
  }

  Future<void> _loadTanks() async {
    final map = <int, Tank>{};
    for (final line in widget.batch.lines) {
      final tank = await _tankRepo.getById(line.tankId);
      if (tank != null) map[line.tankId] = tank;
    }
    if (!mounted) return;
    setState(() {
      _tanksById = map;
      _loadingTanks = false;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<_ReceiptLineCalc> _parseLines() {
    return widget.batch.lines.map((line) {
      final v = double.tryParse(_ctrls[line.id]!.text) ?? 0;
      return _ReceiptLineCalc(
        line: line,
        receivedLiters: v,
        tank: _tanksById[line.tankId],
      );
    }).toList();
  }

  Map<int, double>? _validateAndBuild() {
    if (_loadingTanks) {
      ToastUtils.show(context, 'กำลังโหลดข้อมูลคลัง...');
      return null;
    }
    final out = <int, double>{};
    for (final line in widget.batch.lines) {
      final v = double.tryParse(_ctrls[line.id]!.text);
      if (v == null || v <= 0) {
        ToastUtils.show(context, '${line.fuelName ?? line.tankName}: ปริมาณไม่ถูกต้อง');
        return null;
      }
      final tank = _tanksById[line.tankId];
      if (tank == null) {
        ToastUtils.show(context, '${line.tankName}: ไม่พบข้อมูลคลัง');
        return null;
      }
      if (!tank.canReceive(v)) {
        ToastUtils.show(
          context,
          '${tank.name}: รับ ${Fmt.liters(v)} เกินความจุ '
          '(ว่าง ${Fmt.liters(tank.availableLiters)} / ${Fmt.liters(tank.capacity)})',
        );
        return null;
      }
      out[line.id] = v;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final calcs = _parseLines();
    final totalReceived =
        calcs.fold<double>(0, (s, c) => s + c.receivedLiters);
    final totalOrdered = widget.batch.totalOrderedLiters;
    final totalDiff = totalReceived - totalOrdered;
    final hasCapacityIssue =
        !_loadingTanks && calcs.any((c) => c.exceedsCapacity);
    final canConfirm = !_loadingTanks && !hasCapacityIssue;

    double? totalMoney;
    var hasMoney = false;
    for (final calc in calcs) {
      final share = widget.batch.shippingCost != null && totalReceived > 0
          ? widget.batch.shippingCost! *
              (calc.receivedLiters / totalReceived)
          : null;
      final cost = calc.fuelCost(share);
      if (cost != null) {
        hasMoney = true;
        totalMoney = (totalMoney ?? 0) + cost;
      }
    }

    return Dialog(
      insetPadding: EdgeInsets.all(r.w(12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: r.w(520),
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: EdgeInsets.all(r.w(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.w(6)),
                    decoration: BoxDecoration(
                      color: AppColors.corporateBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_rounded,
                        color: AppColors.corporateBlue, size: r.sp(18)),
                  ),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'บันทึกรับน้ำมัน',
                          style: TextStyle(
                            fontSize: r.sp(13),
                            fontWeight: FontWeight.w900,
                            color: AppColors.corporateBlueDark,
                          ),
                        ),
                        Text(
                          widget.batch.supplierName,
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
                ],
              ),
              SizedBox(height: r.h(8)),
              if (_loadingTanks)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: r.h(8)),
                  child: Center(
                    child: SizedBox(
                      width: r.w(20),
                      height: r.w(20),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: calcs
                          .map(
                            (calc) => _ReceiptLineCard(
                              calc: calc,
                              controller: _ctrls[calc.line.id]!,
                              shippingShare: widget.batch.shippingCost != null &&
                                      totalReceived > 0
                                  ? widget.batch.shippingCost! *
                                      (calc.receivedLiters / totalReceived)
                                  : null,
                              onChanged: () => setState(() {}),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              if (hasCapacityIssue)
                Padding(
                  padding: EdgeInsets.only(top: r.h(4)),
                  child: Text(
                    'ปริมาณรับเกินความจุคลัง — ลดจำนวนรับหรือเช็คสต็อกก่อนยืนยัน',
                    style: TextStyle(
                      fontSize: r.sp(8),
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              Container(
                margin: EdgeInsets.only(top: r.h(6)),
                padding: EdgeInsets.all(r.w(10)),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.greyLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'สรุปรับเข้า',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w900,
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                    SizedBox(height: r.h(4)),
                    _SummaryRow(
                      label: 'รับรวม',
                      value:
                          '${Fmt.liters(totalReceived)} (สั่ง ${Fmt.liters(totalOrdered)})',
                      r: r,
                    ),
                    _SummaryRow(
                      label: 'Diff รวม',
                      value:
                          '${totalDiff >= 0 ? '+' : ''}${Fmt.liters(totalDiff)}',
                      r: r,
                      valueColor: totalDiff == 0
                          ? AppColors.greyDark
                          : totalDiff > 0
                              ? AppColors.success
                              : AppColors.danger,
                    ),
                    if (widget.batch.shippingCost != null)
                      _SummaryRow(
                        label: 'ค่าขนส่ง',
                        value: Fmt.money(widget.batch.shippingCost!),
                        r: r,
                      ),
                    if (hasMoney && totalMoney != null)
                      _SummaryRow(
                        label: 'ยอดเงินรวม',
                        value: Fmt.money(totalMoney!),
                        r: r,
                        valueColor: AppColors.corporateBlueDark,
                        bold: true,
                      ),
                  ],
                ),
              ),
              SizedBox(height: r.h(10)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, r.h(34)),
                        side: const BorderSide(color: AppColors.corporateBlue),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('ยกเลิก',
                          style: TextStyle(fontSize: r.sp(10))),
                    ),
                  ),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        minimumSize: Size(0, r.h(34)),
                        disabledBackgroundColor:
                            AppColors.greyMedium.withValues(alpha: 0.5),
                      ),
                      onPressed: canConfirm
                          ? () {
                              final result = _validateAndBuild();
                              if (result != null) {
                                Navigator.pop(context, result);
                              }
                            }
                          : null,
                      child: Text(
                        'ยืนยันรับ',
                        style: TextStyle(
                          fontSize: r.sp(10),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptLineCard extends StatelessWidget {
  final _ReceiptLineCalc calc;
  final TextEditingController controller;
  final double? shippingShare;
  final VoidCallback onChanged;

  const _ReceiptLineCard({
    required this.calc,
    required this.controller,
    required this.shippingShare,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final line = calc.line;
    final color = fuelColorForName(line.fuelName ?? line.tankName);
    final diff = calc.diffLiters;
    final diffColor = diff == 0
        ? AppColors.greyDark
        : diff > 0
            ? AppColors.success
            : AppColors.danger;
    final lineCost = calc.fuelCost(shippingShare);
    final tank = calc.tank;
    final exceeds = calc.exceedsCapacity;
    final borderColor =
        exceeds ? AppColors.danger : AppColors.greyLight;

    return Container(
      margin: EdgeInsets.only(bottom: r.h(6)),
      padding: EdgeInsets.all(r.w(8)),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: exceeds ? 1.5 : 1),
        borderRadius: BorderRadius.circular(8),
        color: exceeds ? AppColors.danger.withValues(alpha: 0.04) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: r.h(32),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.fuelName ?? line.tankName,
                      style: TextStyle(
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w900,
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                    Text(
                      '${line.tankName} · สั่ง ${Fmt.liters(line.orderedLiters)}'
                      '${line.unitCost != null ? ' · ${Fmt.money(line.unitCost!)}/ล.' : ''}',
                      style: TextStyle(
                        fontSize: r.sp(8),
                        color: AppColors.greyDark,
                      ),
                    ),
                    if (tank != null) ...[
                      SizedBox(height: r.h(2)),
                      Text(
                        'คงเหลือ ${Fmt.liters(tank.currentLiters)} / ${Fmt.liters(tank.capacity)} · '
                        'รับได้สูงสุด ${Fmt.liters(tank.availableLiters)}',
                        style: TextStyle(
                          fontSize: r.sp(8),
                          fontWeight: FontWeight.w700,
                          color: exceeds
                              ? AppColors.danger
                              : AppColors.corporateBlueDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(6)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'รับจริง (ล.)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    labelStyle: TextStyle(fontSize: r.sp(9)),
                    errorText: exceeds
                        ? 'เกิน ${Fmt.liters(calc.overflowLiters)}'
                        : null,
                  ),
                ),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Diff ${diff >= 0 ? '+' : ''}${Fmt.liters(diff)}',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w800,
                        color: diffColor,
                      ),
                    ),
                    if (lineCost != null)
                      Text(
                        'ยอด ${Fmt.money(lineCost!)}',
                        style: TextStyle(
                          fontSize: r.sp(9),
                          fontWeight: FontWeight.w800,
                          color: AppColors.corporateBlueDark,
                        ),
                      )
                    else
                      Text(
                        'ไม่มีราค/ล.',
                        style: TextStyle(
                          fontSize: r.sp(8),
                          color: AppColors.greyMedium,
                        ),
                      ),
                    if (shippingShare != null && shippingShare! > 0)
                      Text(
                        'รวมขนส่ง ${Fmt.money(shippingShare!)}',
                        style: TextStyle(
                          fontSize: r.sp(7),
                          color: AppColors.greyMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Responsive r;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.r,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(2)),
      child: Row(
        children: [
          SizedBox(
            width: r.w(72),
            child: Text(
              label,
              style: TextStyle(
                fontSize: r.sp(8),
                color: AppColors.greyMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: r.sp(9),
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor ?? AppColors.greyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
