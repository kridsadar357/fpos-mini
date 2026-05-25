import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/repositories/customer_repository.dart';
import '../providers/app_state.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

class FleetCardDialog {
  static Future<void> show(BuildContext context) async {
    final r = Responsive.of(context);
    final controller = TextEditingController();
    final repo = CustomerRepository();

    await HighEndDialog.show<void>(
      context: context,
      title: 'บัตรฟลีทการ์ด',
      icon: Icons.credit_card_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'เลขบัตร / ทะเบียนรถ',
              prefixIcon: Icon(Icons.badge_rounded, color: AppColors.corporateBlue),
            ),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'สแกนหรือพิมพ์เลขบัตรฟลีท ระบบจะผูกกับทะเบียนรถ',
            style: TextStyle(color: AppColors.greyMedium, fontSize: r.sp(12)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        SizedBox(
          width: 140,
          child: PrimaryButton(
            label: 'ยืนยัน',
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;
              final customer = await repo.findByFleetCard(code);
              if (!context.mounted) return;
              final state = context.read<AppState>();
              if (customer != null) {
                state.setCustomer(customer);
              }
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
