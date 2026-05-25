import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../providers/app_state.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

class VehiclePlateDialog {
  static Future<void> show(BuildContext context, {String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');

    await HighEndDialog.show<void>(
      context: context,
      title: 'ทะเบียนรถ',
      icon: Icons.directions_car_rounded,
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'เลขทะเบียน',
          hintText: 'กข 1234',
          prefixIcon:
              Icon(Icons.pin_rounded, color: AppColors.corporateBlue),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () {
            context
                .read<AppState>()
                .setVehiclePlate(controller.text.trim().toUpperCase());
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
