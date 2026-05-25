import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../../data/models/shift.dart';
import '../../data/repositories/shift_repository.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

class OpenShiftDialog {
  static Future<Shift?> show(BuildContext context, {required int userId}) async {
    final cashCtrl = TextEditingController(text: '0');
    final r = Responsive.of(context);

    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'เปิดกะขาย',
      message: 'แต่ละพนักงานต้องเปิดกะของตนเองก่อนขาย',
      icon: Icons.schedule_rounded,
      maxWidth: r.w(400),
      content: TextField(
        controller: cashCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'เงินสดในลิ้นชักเริ่มต้น (บาท)',
          hintText: '0',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        PrimaryButton(
          label: 'เปิดกะ',
          expand: false,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    if (ok != true) return null;

    final opening = double.tryParse(cashCtrl.text) ?? 0;
    return ShiftRepository().openShift(
      userId: userId,
      openingCash: opening,
    );
  }
}
