import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fuel_color_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/fuel_import_line.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/tank.dart';
import '../../../data/repositories/fuel_delivery_repository.dart';
import '../../../data/repositories/supplier_repository.dart';
import '../../../data/repositories/tank_repository.dart';
import '../../providers/app_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/supplier_form_dialog.dart';
import '../../widgets/pos_header.dart';

class FuelImportCreateScreen extends StatefulWidget {
  const FuelImportCreateScreen({super.key});

  @override
  State<FuelImportCreateScreen> createState() => _FuelImportCreateScreenState();
}

class _ImportLineEntry {
  int? tankId;
  final litersCtrl = TextEditingController();
  final costCtrl = TextEditingController();

  void dispose() {
    litersCtrl.dispose();
    costCtrl.dispose();
  }
}

class _FuelImportCreateScreenState extends State<FuelImportCreateScreen> {
  final _supplierRepo = SupplierRepository();
  final _tankRepo = TankRepository();
  final _deliveryRepo = FuelDeliveryRepository();

  List<Supplier> _suppliers = [];
  List<Tank> _tanks = [];
  final List<_ImportLineEntry> _lines = [_ImportLineEntry()];
  final _orderNoteCtrl = TextEditingController();
  final _shippingCostCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int? _supplierId;

  static const _inputDecoration = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _orderNoteCtrl.dispose();
    _shippingCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final suppliers = await _supplierRepo.listActive();
    final tanks = await _tankRepo.listAll();
    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _tanks = tanks;
      _supplierId ??= suppliers.isNotEmpty ? suppliers.first.id : null;
      if (_tanks.isNotEmpty) {
        for (final line in _lines) {
          line.tankId ??= _tanks.first.id;
        }
      }
      _loading = false;
    });
  }

  bool get _canSubmit =>
      !_saving && _suppliers.isNotEmpty && _tanks.isNotEmpty;

  void _addLine() {
    if (_tanks.isEmpty) return;
    final used = _lines.map((l) => l.tankId).whereType<int>().toSet();
    final next = _tanks.firstWhere(
      (t) => !used.contains(t.id),
      orElse: () => _tanks.first,
    );
    setState(() => _lines.add(_ImportLineEntry()..tankId = next.id));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() => _lines.removeAt(index).dispose());
  }

  Future<void> _addSupplier() async {
    final created = await SupplierFormDialog.show(context);
    if (created == null || !mounted) return;
    await _load();
    setState(() => _supplierId = created.id);
  }

  List<FuelImportLine>? _parseLines() {
    final parsed = <FuelImportLine>[];
    final usedTanks = <int>{};
    for (var i = 0; i < _lines.length; i++) {
      final entry = _lines[i];
      final tankId = entry.tankId;
      if (tankId == null) {
        ToastUtils.show(context, 'รายการที่ ${i + 1}: กรุณาเลือกถัง');
        return null;
      }
      if (usedTanks.contains(tankId)) {
        ToastUtils.show(context, 'ถังซ้ำในใบสั่งซื้อ');
        return null;
      }
      usedTanks.add(tankId);
      final liters = double.tryParse(entry.litersCtrl.text);
      if (liters == null || liters <= 0) {
        ToastUtils.show(context, 'รายการที่ ${i + 1}: ลิตรไม่ถูกต้อง');
        return null;
      }
      final costText = entry.costCtrl.text.trim();
      parsed.add(FuelImportLine(
        tankId: tankId,
        liters: liters,
        unitCost: costText.isEmpty ? null : double.tryParse(costText),
      ));
    }
    return parsed;
  }

  double? _parseShippingCost() {
    final text = _shippingCostCtrl.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      ToastUtils.show(context, 'ค่าขนส่งไม่ถูกต้อง');
      return null;
    }
    return value;
  }

  Future<void> _submit() async {
    if (_supplierId == null) {
      ToastUtils.show(context, 'กรุณาเลือก Supplier');
      return;
    }
    final lines = _parseLines();
    if (lines == null) return;
    final shippingCost = _parseShippingCost();
    if (_shippingCostCtrl.text.trim().isNotEmpty && shippingCost == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _deliveryRepo.recordBatchImport(
        supplierId: _supplierId!,
        lines: lines,
        userId: context.read<AppState>().user?.id,
        orderNote: _orderNoteCtrl.text.trim().isEmpty
            ? null
            : _orderNoteCtrl.text.trim(),
        shippingCost: shippingCost,
      );
      if (!mounted) return;
      ToastUtils.show(context, 'สร้างใบสั่งซื้อ ${lines.length} รายการแล้ว');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ToastUtils.show(context, 'บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _tankLabel(Tank t) {
    final fuel = t.fuelName ?? '';
    final short = fuel.isNotEmpty ? shortFuelLabel(fuel) : '';
    return short.isNotEmpty ? '${t.name} · $short' : t.name;
  }

  Widget _sectionTitle(String label, Responsive r) {
    return Text(
      label,
      style: TextStyle(
        fontSize: r.sp(10),
        fontWeight: FontWeight.w900,
        color: AppColors.corporateBlueDark,
      ),
    );
  }

  Widget _supplierHeader(Responsive r) {
    return Row(
      children: [
        Expanded(child: _sectionTitle('Supplier', r)),
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(6),
              vertical: r.h(2),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _addSupplier,
          icon: Icon(Icons.add, size: r.sp(14)),
          label: Text('เพิ่ม', style: TextStyle(fontSize: r.sp(9))),
        ),
      ],
    );
  }

  Widget _supplierList(Responsive r) {
    if (_suppliers.isEmpty) {
      return Center(
        child: OutlinedButton(
          onPressed: _addSupplier,
          child: Text('เพิ่ม Supplier แรก', style: TextStyle(fontSize: r.sp(10))),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _suppliers.length,
      separatorBuilder: (_, __) => SizedBox(height: r.h(4)),
      itemBuilder: (context, index) {
        final s = _suppliers[index];
        final sel = s.id == _supplierId;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _supplierId = s.id),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.w(8),
                vertical: r.h(7),
              ),
              decoration: BoxDecoration(
                color: sel ? AppColors.corporateBlueDark : AppColors.softWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel ? AppColors.corporateBlueDark : AppColors.greyLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: r.sp(15),
                    color: sel ? AppColors.white : AppColors.greyMedium,
                  ),
                  SizedBox(width: r.w(6)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.documentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.sp(10),
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? AppColors.white
                                : AppColors.corporateBlueDark,
                          ),
                        ),
                        if (s.taxId != null && s.taxId!.trim().isNotEmpty)
                          Text(
                            s.taxId!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: r.sp(8),
                              color: sel
                                  ? AppColors.white.withValues(alpha: 0.85)
                                  : AppColors.greyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metaRow(Responsive r) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _shippingCostCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration.copyWith(
              labelText: 'ค่าขนส่ง (฿)',
              labelStyle: TextStyle(fontSize: r.sp(10)),
            ),
          ),
        ),
        SizedBox(width: r.w(8)),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _orderNoteCtrl,
            decoration: _inputDecoration.copyWith(
              labelText: 'หมายเหตุ',
              labelStyle: TextStyle(fontSize: r.sp(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _lineRow(int index, _ImportLineEntry entry, Responsive r) {
    return Container(
      margin: EdgeInsets.only(bottom: r.h(4)),
      padding: EdgeInsets.symmetric(
        horizontal: r.w(6),
        vertical: r.h(4),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.greyLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.w(20),
            child: Padding(
              padding: EdgeInsets.only(top: r.h(10)),
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: r.sp(9),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<int>(
              initialValue: entry.tankId,
              isDense: true,
              isExpanded: true,
              decoration: _inputDecoration.copyWith(
                labelText: 'ถัง / ชนิด',
                labelStyle: TextStyle(fontSize: r.sp(9)),
              ),
              items: _tanks
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          _tankLabel(t),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: r.sp(10)),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => entry.tankId = v),
            ),
          ),
          SizedBox(width: r.w(6)),
          Expanded(
            flex: 2,
            child: TextField(
              controller: entry.litersCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration.copyWith(
                labelText: 'ลิตร *',
                labelStyle: TextStyle(fontSize: r.sp(9)),
              ),
            ),
          ),
          SizedBox(width: r.w(6)),
          Expanded(
            flex: 2,
            child: TextField(
              controller: entry.costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration.copyWith(
                labelText: '฿/ลิตร',
                labelStyle: TextStyle(fontSize: r.sp(9)),
              ),
            ),
          ),
          if (_lines.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: r.w(24),
                minHeight: r.h(24),
              ),
              icon: Icon(Icons.close, size: r.sp(15)),
              onPressed: () => _removeLine(index),
            ),
        ],
      ),
    );
  }

  Widget _linesHeader(Responsive r) {
    return Row(
      children: [
        Expanded(
          child: _sectionTitle('รายการ (${_lines.length})', r),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(6),
              vertical: r.h(2),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _tanks.isEmpty ? null : _addLine,
          icon: Icon(Icons.add_circle_outline, size: r.sp(14)),
          label: Text('เพิ่มชนิด', style: TextStyle(fontSize: r.sp(9))),
        ),
      ],
    );
  }

  Widget _linesList(Responsive r) {
    return ListView(
      padding: EdgeInsets.zero,
      children: List.generate(
        _lines.length,
        (i) => _lineRow(i, _lines[i], r),
      ),
    );
  }

  Widget _wideLayout(Responsive r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _supplierHeader(r),
              SizedBox(height: r.h(6)),
              Expanded(child: _supplierList(r)),
              SizedBox(height: r.h(8)),
              _metaRow(r),
            ],
          ),
        ),
        SizedBox(width: r.w(12)),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _linesHeader(r),
              SizedBox(height: r.h(6)),
              Expanded(child: _linesList(r)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _supplierHeader(r),
        SizedBox(height: r.h(6)),
        Expanded(flex: 2, child: _supplierList(r)),
        SizedBox(height: r.h(8)),
        _metaRow(r),
        SizedBox(height: r.h(8)),
        _linesHeader(r),
        SizedBox(height: r.h(6)),
        Expanded(flex: 3, child: _linesList(r)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'สร้างใบสั่งซื้อน้ำมัน',
        subtitle: 'หลายชนิดต่อ Supplier · รอบันทึกรับ',
        onBack: () => Navigator.pop(context),
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
              onPressed: _canSubmit ? _submit : null,
              icon: _saving
                  ? SizedBox(
                      width: r.sp(14),
                      height: r.sp(14),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Icon(Icons.save_rounded,
                      color: AppColors.white, size: r.sp(16)),
              label: Text(
                'บันทึก',
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final padH = r.w(8);
                final padTop = r.h(6);
                final padBottom = r.h(8);
                final cardHeight =
                    constraints.maxHeight - padTop - padBottom;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    padH,
                    padTop,
                    padH,
                    padBottom,
                  ),
                  child: SizedBox(
                    height: cardHeight,
                    width: constraints.maxWidth,
                    child: GlassCard(
                      padding: EdgeInsets.all(r.w(10)),
                      borderRadius: r.r(10),
                      child: wide ? _wideLayout(r) : _narrowLayout(r),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
