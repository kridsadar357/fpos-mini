import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/supplier.dart';
import '../../data/repositories/supplier_repository.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

/// ฟอร์มเพิ่ม/แก้ไข Supplier (ข้อมูลเอกสารรับน้ำมัน)
class SupplierFormDialog {
  static Future<Supplier?> show(
    BuildContext context, {
    Supplier? existing,
  }) async {
    final r = Responsive.of(context);
    final repo = SupplierRepository();
    final formKey = GlobalKey<_SupplierFormContentState>();
    final isEdit = existing?.id != null;

    final supplier = await HighEndDialog.show<Supplier?>(
      context: context,
      title: isEdit ? 'แก้ไข Supplier' : 'เพิ่ม Supplier',
      icon: Icons.local_shipping_rounded,
      maxWidth: r.w(560),
      content: _SupplierFormContent(
        key: formKey,
        r: r,
        existing: existing,
      ),
      actionBuilders: (dialogContext) => [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => HighEndDialog.close(dialogContext, null),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () {
            final data = formKey.currentState?.buildSupplier();
            if (data == null) return;
            HighEndDialog.close(dialogContext, data);
          },
        ),
      ],
    );

    if (supplier == null) return null;

    if (isEdit) {
      await repo.update(supplier);
      return supplier;
    }

    final id = await repo.create(supplier);
    return Supplier(
      id: id,
      name: supplier.name,
      company: supplier.company,
      taxId: supplier.taxId,
      branchNo: supplier.branchNo,
      address: supplier.address,
      postalCode: supplier.postalCode,
      phone: supplier.phone,
      email: supplier.email,
      contactName: supplier.contactName,
      note: supplier.note,
      supplierType: supplier.supplierType,
      createdAt: supplier.createdAt,
    );
  }
}

class _SupplierFormContent extends StatefulWidget {
  final Responsive r;
  final Supplier? existing;

  const _SupplierFormContent({
    super.key,
    required this.r,
    this.existing,
  });

  @override
  State<_SupplierFormContent> createState() => _SupplierFormContentState();
}

class _SupplierFormContentState extends State<_SupplierFormContent> {
  late String _type;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.supplierType ?? Supplier.typeCompany;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _companyCtrl = TextEditingController(text: e?.company ?? '');
    _taxCtrl = TextEditingController(text: e?.taxId ?? '');
    _branchCtrl = TextEditingController(text: e?.branchNo ?? '00000');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _zipCtrl = TextEditingController(text: e?.postalCode ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _contactCtrl = TextEditingController(text: e?.contactName ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _taxCtrl.dispose();
    _branchCtrl.dispose();
    _addressCtrl.dispose();
    _zipCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Supplier? buildSupplier() {
    if (_nameCtrl.text.trim().isEmpty) return null;

    return Supplier(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      company: _trimOrNull(_companyCtrl.text),
      taxId: _trimOrNull(_taxCtrl.text),
      branchNo: _branchCtrl.text.trim().isEmpty
          ? '00000'
          : _branchCtrl.text.trim(),
      address: _trimOrNull(_addressCtrl.text),
      postalCode: _trimOrNull(_zipCtrl.text),
      phone: _trimOrNull(_phoneCtrl.text),
      email: _trimOrNull(_emailCtrl.text),
      contactName: _trimOrNull(_contactCtrl.text),
      note: _trimOrNull(_noteCtrl.text),
      supplierType: _type,
      isActive: widget.existing?.isActive ?? true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
  }

  String? _trimOrNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _CompactSupplierForm(
        r: widget.r,
        type: _type,
        onTypeChanged: (t) => setState(() => _type = t),
        nameCtrl: _nameCtrl,
        companyCtrl: _companyCtrl,
        taxCtrl: _taxCtrl,
        branchCtrl: _branchCtrl,
        addressCtrl: _addressCtrl,
        zipCtrl: _zipCtrl,
        phoneCtrl: _phoneCtrl,
        emailCtrl: _emailCtrl,
        contactCtrl: _contactCtrl,
        noteCtrl: _noteCtrl,
      ),
    );
  }
}

class _CompactSupplierForm extends StatelessWidget {
  final Responsive r;
  final String type;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController nameCtrl;
  final TextEditingController companyCtrl;
  final TextEditingController taxCtrl;
  final TextEditingController branchCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController zipCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController contactCtrl;
  final TextEditingController noteCtrl;

  const _CompactSupplierForm({
    required this.r,
    required this.type,
    required this.onTypeChanged,
    required this.nameCtrl,
    required this.companyCtrl,
    required this.taxCtrl,
    required this.branchCtrl,
    required this.addressCtrl,
    required this.zipCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.contactCtrl,
    required this.noteCtrl,
  });

  bool get isCompany => type == Supplier.typeCompany;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: r.sp(11));
    final fieldGap = r.h(6);
    final colGap = r.w(6);

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: labelStyle,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: r.w(10),
            vertical: r.h(8),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        );

    Widget field(
      TextEditingController ctrl,
      String label, {
      String? hint,
      TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      int maxLines = 1,
    }) {
      return TextField(
        controller: ctrl,
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLines: maxLines,
        style: TextStyle(fontSize: r.sp(12)),
        decoration: deco(label, hint: hint),
      );
    }

    Widget row2(Widget left, Widget right) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: colGap),
            Expanded(child: right),
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ข้อมูลสำหรับออกเอกสารรับน้ำมัน / ใบกำกับภาษี',
          style: TextStyle(
            fontSize: r.sp(11),
            color: AppColors.greyMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: fieldGap),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: Supplier.typeCompany,
              label: Text('นิติบุคคล', style: TextStyle(fontSize: r.sp(11))),
            ),
            ButtonSegment(
              value: Supplier.typeIndividual,
              label: Text('บุคคลธรรมดา', style: TextStyle(fontSize: r.sp(11))),
            ),
          ],
          selected: {type},
          onSelectionChanged: (s) => onTypeChanged(s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: r.w(6), vertical: r.h(2)),
            ),
          ),
        ),
        SizedBox(height: fieldGap),
        if (isCompany)
          row2(
            field(nameCtrl, 'ชื่อเรียก / ชื่อย่อ *'),
            field(companyCtrl, 'ชื่อนิติบุคคล (บนเอกสาร)'),
          )
        else
          field(nameCtrl, 'ชื่อ-นามสกุล *'),
        SizedBox(height: fieldGap),
        row2(
          field(
            taxCtrl,
            'เลขผู้เสียภาษี',
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
          ),
          field(
            branchCtrl,
            'รหัสสาขา',
            hint: '00000',
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
          ),
        ),
        SizedBox(height: fieldGap),
        field(
          addressCtrl,
          'ที่อยู่ (ใบกำกับ)',
          maxLines: 2,
        ),
        SizedBox(height: fieldGap),
        row2(
          field(zipCtrl, 'รหัสไปรษณีย์', keyboard: TextInputType.number),
          field(phoneCtrl, 'โทรศัพท์', keyboard: TextInputType.phone),
        ),
        SizedBox(height: fieldGap),
        row2(
          field(emailCtrl, 'อีเมล', keyboard: TextInputType.emailAddress),
          field(contactCtrl, 'ผู้ติดต่อ'),
        ),
        SizedBox(height: fieldGap),
        field(noteCtrl, 'หมายเหตุ (เอกสาร)'),
      ],
    );
  }
}
