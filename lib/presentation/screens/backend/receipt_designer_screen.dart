import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/bluetooth_printer_service.dart';
import '../../../core/services/receipt_template_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/receipt_template.dart';
import '../../../data/models/transaction.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';

class ReceiptDesignerScreen extends StatefulWidget {
  const ReceiptDesignerScreen({super.key});

  @override
  State<ReceiptDesignerScreen> createState() => _ReceiptDesignerScreenState();
}

class _ReceiptDesignerScreenState extends State<ReceiptDesignerScreen> {
  ReceiptTemplate _template = const ReceiptTemplate();
  bool _loading = true;
  bool _saving = false;

  final _headerControllers = <TextEditingController>[];
  final _footerControllers = <TextEditingController>[];

  Map<String, String> _previewValues = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _headerControllers) {
      c.dispose();
    }
    for (final c in _footerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    for (final c in _headerControllers) {
      c.dispose();
    }
    for (final c in _footerControllers) {
      c.dispose();
    }
    _headerControllers.clear();
    _footerControllers.clear();
    for (final line in _template.headerLines) {
      _headerControllers.add(TextEditingController(text: line));
    }
    for (final line in _template.footerLines) {
      _footerControllers.add(TextEditingController(text: line));
    }
  }

  Future<void> _load() async {
    final tpl = await ReceiptTemplateService.instance.load();
    final repo = SettingsRepository();
    final preview = {
      'station_name':
          await repo.get('station_name', defaultValue: 'FUEL POS STATION'),
      'station_address':
          await repo.get('station_address', defaultValue: '123 ถ.ตัวอย่าง'),
      'tax_id': await repo.get('station_tax_id', defaultValue: '0000000000000'),
      'receipt_footer': await repo.get('receipt_footer',
          defaultValue: 'ขอบคุณที่ใช้บริการ — เดินทางปลอดภัย'),
      'receipt_no': 'TX-PREVIEW',
      'date': '22/05/2026 10:30',
      'cashier': 'แคชเชียร์',
      'plate': 'กข 1234',
    };
    setState(() {
      _template = tpl;
      _previewValues = preview;
      _loading = false;
    });
    _syncControllers();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final order = List<ReceiptBlockType>.from(_template.blockOrder);
      final item = order.removeAt(oldIndex);
      order.insert(newIndex, item);
      _template = _template.copyWith(blockOrder: order);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final header = _headerControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final footer = _footerControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final updated = _template.copyWith(
      headerLines: header.isEmpty ? ['{station_name}'] : header,
      footerLines: footer.isEmpty ? ['{receipt_footer}'] : footer,
    );
    await ReceiptTemplateService.instance.save(updated);
    if (!mounted) return;
    setState(() {
      _template = updated;
      _saving = false;
    });
    ToastUtils.show(context, 'บันทึกแม่แบบใบเสร็จแล้ว');
  }

  Future<void> _testPrint() async {
    await _save();
    final draft = Transaction.draft(
      cashierId: 1,
      fuelTypeId: 1,
      paymentMethod: 'CASH',
      liters: 10,
      pricePerLiter: 37.5,
      subtotal: 375,
      total: 375,
      notes:
          'ลูกค้า: บริษัท ตัวอย่าง จำกัด\nเลขผู้เสียภาษี: 0105551234567\nทะเบียนรถ: กข 1234',
    );
    final ok = await BluetoothPrinterService.instance.printReceipt(
      tx: draft,
      fuelName: 'แก๊สโซฮอล์ 95',
      cashierName: 'ทดสอบ',
      isDraft: true,
    );
    if (!mounted) return;
    ToastUtils.show(
      context,
      ok ? 'พิมพ์ตัวอย่างแล้ว' : 'เชื่อมต่อเครื่องพิมพ์ไม่ได้',
    );
  }

  void _addLine({required bool header}) {
    setState(() {
      if (header) {
        _headerControllers.add(TextEditingController(text: '{station_name}'));
      } else {
        _footerControllers
            .add(TextEditingController(text: '{receipt_footer}'));
      }
    });
  }

  void _removeLine({required bool header, required int index}) {
    setState(() {
      if (header) {
        _headerControllers[index].dispose();
        _headerControllers.removeAt(index);
      } else {
        _footerControllers[index].dispose();
        _footerControllers.removeAt(index);
      }
    });
  }

  void _insertPlaceholder(TextEditingController ctrl, String token) {
    final text = ctrl.text;
    ctrl.text = text.isEmpty ? token : '$text $token';
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    setState(() {});
  }

  List<Widget> _previewBlocks(Responsive r) {
    final widgets = <Widget>[];
    for (final block in _template.blockOrder) {
      switch (block) {
        case ReceiptBlockType.logo:
          if (_template.logoEnabled) {
            widgets.add(
              Center(
                child: Container(
                  width: r.w(56),
                  height: r.w(56),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.greyLight),
                  ),
                  child: Icon(
                    Icons.local_gas_station_rounded,
                    color: AppColors.corporateBlue,
                    size: r.sp(28),
                  ),
                ),
              ),
            );
            widgets.add(SizedBox(height: r.h(8)));
          }
          break;
        case ReceiptBlockType.header:
          for (var i = 0; i < _headerControllers.length; i++) {
            final line = ReceiptPlaceholders.apply(
              _headerControllers[i].text,
              _previewValues,
            );
            if (line.isEmpty) continue;
            widgets.add(
              Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: i == 0 ? FontWeight.w900 : FontWeight.w600,
                  fontSize: r.sp(i == 0 ? 13 : 10),
                  height: 1.35,
                ),
              ),
            );
          }
          widgets.add(Padding(
            padding: EdgeInsets.symmetric(vertical: r.h(6)),
            child: const Divider(height: 1, color: AppColors.black),
          ));
          break;
        case ReceiptBlockType.body:
          widgets.addAll([
            _previewRow(r, 'Receipt', _previewValues['receipt_no']!),
            _previewRow(r, 'น้ำมัน', 'แก๊สโซฮอล์ 95'),
            _previewRow(r, 'ลิตร', '10.00'),
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.h(4)),
              child: const Divider(height: 1, color: AppColors.black),
            ),
            _previewRow(r, 'รวม', '375.00', bold: true),
          ]);
          break;
        case ReceiptBlockType.footer:
          widgets.add(Padding(
            padding: EdgeInsets.symmetric(vertical: r.h(4)),
            child: const Divider(height: 1, color: AppColors.black),
          ));
          for (final c in _footerControllers) {
            final line = ReceiptPlaceholders.apply(c.text, _previewValues);
            if (line.isEmpty) continue;
            widgets.add(
              Text(
                line,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: r.sp(10), height: 1.35),
              ),
            );
          }
          break;
      }
    }
    return widgets;
  }

  Widget _previewRow(Responsive r, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: r.sp(10))),
          Text(
            value,
            style: TextStyle(
              fontSize: r.sp(bold ? 13 : 10),
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(Responsive r) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: 'บันทึก',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _save,
          ),
        ),
        SizedBox(width: r.w(8)),
        Expanded(
          child: PrimaryButton(
            label: 'พิมพ์ทดสอบ',
            icon: Icons.print_rounded,
            variant: ButtonVariant.outline,
            onPressed: _testPrint,
          ),
        ),
      ],
    );
  }

  Widget _previewPanel(Responsive r) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  color: AppColors.corporateBlue, size: r.sp(16)),
              SizedBox(width: r.w(6)),
              Text(
                'ตัวอย่างใบเสร็จ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: r.sp(12),
                  color: AppColors.corporateBlueDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.w(8), vertical: r.h(2)),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(r.r(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: r.sp(6), color: AppColors.success),
                    SizedBox(width: r.w(4)),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(10)),
          Center(
            child: Container(
              width: r.w(260).clamp(220.0, 300.0),
              padding: EdgeInsets.symmetric(
                  horizontal: r.w(14), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(r.r(4)),
                border: Border.all(color: AppColors.greyLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _previewBlocks(r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final pad = r.w(12);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'ออกแบบใบเสร็จ',
        subtitle: 'ลากเรียงบล็อก · แก้ header/footer · ดูตัวอย่างสด',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;

                final editorChildren = <Widget>[
                  _BlockOrderPanel(
                    r: r,
                    template: _template,
                    onReorder: _reorder,
                    onLogoToggle: (v) => setState(
                      () => _template = _template.copyWith(logoEnabled: v),
                    ),
                  ),
                  SizedBox(height: pad),
                  _LineEditor(
                    r: r,
                    title: 'หัวใบเสร็จ',
                    subtitle: 'Header — แสดงด้านบนใบเสร็จ',
                    icon: Icons.title_rounded,
                    controllers: _headerControllers,
                    onAdd: () => _addLine(header: true),
                    onRemove: (i) => _removeLine(header: true, index: i),
                    onInsert: _insertPlaceholder,
                    onChanged: () => setState(() {}),
                  ),
                  SizedBox(height: pad),
                  _LineEditor(
                    r: r,
                    title: 'ท้ายใบเสร็จ',
                    subtitle: 'Footer — แสดงด้านล่างใบเสร็จ',
                    icon: Icons.notes_rounded,
                    controllers: _footerControllers,
                    onAdd: () => _addLine(header: false),
                    onRemove: (i) => _removeLine(header: false, index: i),
                    onInsert: _insertPlaceholder,
                    onChanged: () => setState(() {}),
                  ),
                  SizedBox(height: pad),
                  GlassCard(
                    padding: EdgeInsets.all(r.w(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: r.sp(14),
                                color: AppColors.corporateBlue),
                            SizedBox(width: r.w(6)),
                            Text(
                              'ตัวแปรที่ใช้ได้',
                              style: TextStyle(
                                fontSize: r.sp(11),
                                fontWeight: FontWeight.w800,
                                color: AppColors.corporateBlueDark,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: r.h(6)),
                        Text(
                          ReceiptPlaceholders.help.trim(),
                          style: TextStyle(
                            color: AppColors.greyMedium,
                            fontSize: r.sp(9),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!wide) ...[
                    SizedBox(height: pad),
                    _previewPanel(r),
                    SizedBox(height: pad),
                    _actionButtons(r),
                  ],
                ];

                if (wide) {
                  return Padding(
                    padding: EdgeInsets.all(pad),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ListView(children: editorChildren),
                        ),
                        SizedBox(width: pad),
                        SizedBox(
                          width: r.w(320).clamp(280.0, 360.0),
                          child: Column(
                            children: [
                              _previewPanel(r),
                              SizedBox(height: pad),
                              _actionButtons(r),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.all(pad),
                  children: editorChildren,
                );
              },
            ),
    );
  }
}

class _BlockOrderPanel extends StatelessWidget {
  final Responsive r;
  final ReceiptTemplate template;
  final void Function(int, int) onReorder;
  final ValueChanged<bool> onLogoToggle;

  const _BlockOrderPanel({
    required this.r,
    required this.template,
    required this.onReorder,
    required this.onLogoToggle,
  });

  IconData _iconFor(ReceiptBlockType block) {
    switch (block) {
      case ReceiptBlockType.logo:
        return Icons.image_rounded;
      case ReceiptBlockType.header:
        return Icons.title_rounded;
      case ReceiptBlockType.body:
        return Icons.receipt_long_rounded;
      case ReceiptBlockType.footer:
        return Icons.notes_rounded;
    }
  }

  String _hintFor(ReceiptBlockType block) {
    switch (block) {
      case ReceiptBlockType.logo:
        return 'โลโก้จากแอป';
      case ReceiptBlockType.header:
        return 'แก้ข้อความด้านล่าง';
      case ReceiptBlockType.body:
        return 'รายการขาย (อัตโนมัติ)';
      case ReceiptBlockType.footer:
        return 'แก้ข้อความด้านล่าง';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ลำดับบล็อก',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: r.sp(12),
              color: AppColors.corporateBlueDark,
            ),
          ),
          SizedBox(height: r.h(4)),
          Text(
            'ลากเพื่อเรียงลำดับบนใบเสร็จ',
            style: TextStyle(fontSize: r.sp(9), color: AppColors.greyMedium),
          ),
          SizedBox(height: r.h(10)),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: template.blockOrder.length,
            onReorder: onReorder,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(r.r(10)),
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final block = template.blockOrder[index];
              return Container(
                key: ValueKey(block.name),
                margin: EdgeInsets.only(bottom: r.h(6)),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(r.r(10)),
                  border: Border.all(color: AppColors.greyLight),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: r.w(8), vertical: r.h(2)),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      width: r.w(32),
                      height: r.w(32),
                      decoration: BoxDecoration(
                        color: AppColors.corporateBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(r.r(8)),
                      ),
                      child: Icon(Icons.drag_indicator_rounded,
                          color: AppColors.corporateBlue, size: r.sp(18)),
                    ),
                  ),
                  title: Row(
                    children: [
                      Icon(_iconFor(block),
                          size: r.sp(14), color: AppColors.corporateBlue),
                      SizedBox(width: r.w(6)),
                      Text(
                        block.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: r.sp(11),
                          color: AppColors.corporateBlueDark,
                        ),
                      ),
                      SizedBox(width: r.w(6)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.w(6), vertical: r.h(1)),
                        decoration: BoxDecoration(
                          color: AppColors.greyLight,
                          borderRadius: BorderRadius.circular(r.r(6)),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: r.sp(9),
                            fontWeight: FontWeight.w800,
                            color: AppColors.greyDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _hintFor(block),
                    style: TextStyle(fontSize: r.sp(9)),
                  ),
                  trailing: block == ReceiptBlockType.logo
                      ? Switch(
                          value: template.logoEnabled,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: onLogoToggle,
                        )
                      : Icon(Icons.lock_outline_rounded,
                          size: r.sp(16), color: AppColors.greyLight),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  final Responsive r;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(TextEditingController, String) onInsert;
  final VoidCallback onChanged;

  const _LineEditor({
    required this.r,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
    required this.onInsert,
    required this.onChanged,
  });

  static const _tokens = [
    '{station_name}',
    '{station_address}',
    '{tax_id}',
    '{receipt_footer}',
    '{receipt_no}',
    '{date}',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.corporateBlue, size: r.sp(16)),
              SizedBox(width: r.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: r.sp(12),
                        color: AppColors.corporateBlueDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: r.sp(9),
                        color: AppColors.greyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.corporateBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.r(8)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(r.r(8)),
                  onTap: onAdd,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.w(10), vertical: r.h(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: r.sp(14), color: AppColors.corporateBlue),
                        SizedBox(width: r.w(4)),
                        Text(
                          'เพิ่มบรรทัด',
                          style: TextStyle(
                            fontSize: r.sp(10),
                            fontWeight: FontWeight.w700,
                            color: AppColors.corporateBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(10)),
          Wrap(
            spacing: r.w(6),
            runSpacing: r.h(6),
            children: _tokens
                .map(
                  (t) => Material(
                    color: AppColors.softWhite,
                    borderRadius: BorderRadius.circular(r.r(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(r.r(16)),
                      onTap: () {
                        if (controllers.isNotEmpty) {
                          onInsert(controllers.last, t);
                          onChanged();
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.w(8), vertical: r.h(4)),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.r(16)),
                          border: Border.all(color: AppColors.greyLight),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: r.sp(9),
                            fontWeight: FontWeight.w700,
                            color: AppColors.corporateBlueDark,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: r.h(10)),
          ...List.generate(controllers.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: r.h(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: r.w(24),
                    height: r.h(40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.corporateBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(r.r(6)),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w900,
                        color: AppColors.corporateBlue,
                      ),
                    ),
                  ),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: TextField(
                      controller: controllers[i],
                      style: TextStyle(
                        fontSize: r.sp(11),
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความหรือแตะตัวแปรด้านบน',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.r(10)),
                          borderSide:
                              const BorderSide(color: AppColors.greyLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.r(10)),
                          borderSide:
                              const BorderSide(color: AppColors.greyLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.r(10)),
                          borderSide: const BorderSide(
                            color: AppColors.corporateBlue,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger, size: r.sp(20)),
                    onPressed: controllers.length > 1
                        ? () => onRemove(i)
                        : null,
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
