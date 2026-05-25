import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/responsive.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

/// ฟอร์มเพิ่ม/แก้ไขลูกค้า (ข้อมูลใบกำกับภาษี) — layout กระชับ ไม่ scroll
class CustomerFormDialog {
  static Future<Customer?> show(
    BuildContext context, {
    Customer? existing,
  }) async {
    final r = Responsive.of(context);
    final repo = CustomerRepository();

    String type = existing?.customerType ?? Customer.typeCompany;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final taxCtrl = TextEditingController(text: existing?.taxId ?? '');
    final branchCtrl =
        TextEditingController(text: existing?.branchNo ?? '00000');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final zipCtrl = TextEditingController(text: existing?.postalCode ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final contactCtrl =
        TextEditingController(text: existing?.contactName ?? '');
    final plateCtrl =
        TextEditingController(text: existing?.vehiclePlate ?? '');
    final fleetCtrl =
        TextEditingController(text: existing?.fleetCardNo ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    final isEdit = existing?.id != null;

    final saved = await HighEndDialog.show<bool>(
      context: context,
      title: isEdit ? 'แก้ไขลูกค้า' : 'เพิ่มลูกค้า',
      compact: true,
      maxWidth: r.w(540),
      content: StatefulBuilder(
        builder: (ctx, setLocal) {
          return _CompactCustomerForm(
            r: r,
            type: type,
            onTypeChanged: (t) => setLocal(() => type = t),
            nameCtrl: nameCtrl,
            companyCtrl: companyCtrl,
            taxCtrl: taxCtrl,
            branchCtrl: branchCtrl,
            addressCtrl: addressCtrl,
            zipCtrl: zipCtrl,
            phoneCtrl: phoneCtrl,
            emailCtrl: emailCtrl,
            contactCtrl: contactCtrl,
            plateCtrl: plateCtrl,
            fleetCtrl: fleetCtrl,
            noteCtrl: noteCtrl,
          );
        },
      ),
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return null;

    final customer = Customer(
      id: existing?.id,
      name: nameCtrl.text.trim(),
      company: companyCtrl.text.trim().isEmpty
          ? null
          : companyCtrl.text.trim(),
      taxId: taxCtrl.text.trim().isEmpty ? null : taxCtrl.text.trim(),
      branchNo: branchCtrl.text.trim().isEmpty
          ? '00000'
          : branchCtrl.text.trim(),
      address: addressCtrl.text.trim().isEmpty
          ? null
          : addressCtrl.text.trim(),
      postalCode:
          zipCtrl.text.trim().isEmpty ? null : zipCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      contactName: contactCtrl.text.trim().isEmpty
          ? null
          : contactCtrl.text.trim(),
      vehiclePlate: plateCtrl.text.trim().isEmpty
          ? null
          : plateCtrl.text.trim().toUpperCase(),
      fleetCardNo: fleetCtrl.text.trim().isEmpty
          ? null
          : fleetCtrl.text.trim(),
      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      customerType: type,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    if (isEdit) {
      await repo.update(customer);
      return customer;
    }

    final id = await repo.create(
      name: customer.name,
      company: customer.company,
      taxId: customer.taxId,
      branchNo: customer.branchNo,
      address: customer.address,
      postalCode: customer.postalCode,
      phone: customer.phone,
      email: customer.email,
      contactName: customer.contactName,
      customerType: customer.customerType,
      vehiclePlate: customer.vehiclePlate,
      fleetCardNo: customer.fleetCardNo,
      note: customer.note,
    );
    return Customer(
      id: id,
      name: customer.name,
      company: customer.company,
      taxId: customer.taxId,
      branchNo: customer.branchNo,
      address: customer.address,
      postalCode: customer.postalCode,
      phone: customer.phone,
      email: customer.email,
      contactName: customer.contactName,
      customerType: customer.customerType,
      vehiclePlate: customer.vehiclePlate,
      fleetCardNo: customer.fleetCardNo,
      note: customer.note,
      createdAt: customer.createdAt,
    );
  }
}

class _CompactCustomerForm extends StatelessWidget {
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
  final TextEditingController plateCtrl;
  final TextEditingController fleetCtrl;
  final TextEditingController noteCtrl;

  const _CompactCustomerForm({
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
    required this.plateCtrl,
    required this.fleetCtrl,
    required this.noteCtrl,
  });

  bool get isCompany => type == Customer.typeCompany;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: r.sp(11));
    final fieldGap = r.h(4);
    final colGap = r.w(6);

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
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
      TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      TextCapitalization capitalization = TextCapitalization.none,
    }) {
      return TextField(
        controller: ctrl,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: capitalization,
        style: TextStyle(fontSize: r.sp(12)),
        decoration: deco(label),
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
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: Customer.typeCompany,
              label: Text('นิติบุคคล', style: TextStyle(fontSize: r.sp(11))),
            ),
            ButtonSegment(
              value: Customer.typeIndividual,
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
            field(nameCtrl, 'ชื่อเรียก / ชื่อย่อ'),
            field(companyCtrl, 'ชื่อนิติบุคคล'),
          )
        else
          field(
            nameCtrl,
            isCompany ? 'ชื่อเรียก' : 'ชื่อ-นามสกุล',
          ),
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
            keyboard: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
          ),
        ),
        SizedBox(height: fieldGap),
        field(addressCtrl, 'ที่อยู่ (ใบกำกับ)'),
        SizedBox(height: fieldGap),
        row2(
          field(zipCtrl, 'ไปรษณีย์', keyboard: TextInputType.number),
          field(phoneCtrl, 'โทร', keyboard: TextInputType.phone),
        ),
        SizedBox(height: fieldGap),
        row2(
          field(emailCtrl, 'อีเมล', keyboard: TextInputType.emailAddress),
          field(contactCtrl, 'ผู้ติดต่อ'),
        ),
        SizedBox(height: fieldGap),
        row2(
          field(
            plateCtrl,
            'ทะเบียนรถ',
            capitalization: TextCapitalization.characters,
          ),
          field(fleetCtrl, 'บัตรฟลีท'),
        ),
        SizedBox(height: fieldGap),
        field(noteCtrl, 'หมายเหตุ'),
      ],
    );
  }
}
