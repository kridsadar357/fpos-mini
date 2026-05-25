import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/money_utils.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/shift_summary.dart';
import '../../data/repositories/shift_repository.dart';
import 'high_end_dialog.dart';
import 'primary_button.dart';

enum CloseShiftOutcome {
  cancelled,
  openedNewShift,
  logout,
}

class CloseShiftDialog {
  static Future<CloseShiftOutcome> show(
    BuildContext context, {
    required int shiftId,
    required int userId,
  }) async {
    final repo = ShiftRepository();
    final summary = await repo.buildSummary(shiftId);
    if (!context.mounted) return CloseShiftOutcome.cancelled;
    if (summary == null) return CloseShiftOutcome.cancelled;

    final r = Responsive.of(context);
    final cashCtrl = TextEditingController(
      text: MoneyUtils.ceilBaht(summary.expectedDrawerCash).toStringAsFixed(0),
    );

    try {
      final confirmed = await HighEndDialog.show<bool>(
        context: context,
        title: 'ปิดกะขาย',
        icon: Icons.lock_clock_rounded,
        iconColor: AppColors.gold,
        maxWidth: r.w(480),
        barrierDismissible: false,
        content: _ShiftClosePanel(
          summary: summary,
          cashController: cashCtrl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(color: AppColors.greyMedium),
            ),
          ),
          PrimaryButton(
            label: 'ยืนยันปิดกะ',
            icon: Icons.check_circle_rounded,
            expand: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );

      if (confirmed != true || !context.mounted) {
        return CloseShiftOutcome.cancelled;
      }

      final closing = MoneyUtils.ceilBaht(double.tryParse(cashCtrl.text) ?? 0);
      await repo.closeShift(
        shiftId: shiftId,
        userId: userId,
        closingCash: closing,
      );
    } finally {
      cashCtrl.dispose();
    }

    if (!context.mounted) return CloseShiftOutcome.logout;

    final next = await HighEndDialog.show<CloseShiftOutcome>(
      context: context,
      title: 'ปิดกะสำเร็จ',
      message: 'กะ #${summary.shift.id} ปิดแล้ว\nยอดขายรวม ${Fmt.money(summary.totalSales)}',
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      maxWidth: r.w(400),
      actions: [
        PrimaryButton(
          label: 'เปิดกะใหม่',
          icon: Icons.schedule_rounded,
          onPressed: () =>
              Navigator.pop(context, CloseShiftOutcome.openedNewShift),
        ),
        PrimaryButton(
          label: 'ออกจากระบบ',
          variant: ButtonVariant.outline,
          icon: Icons.logout_rounded,
          onPressed: () => Navigator.pop(context, CloseShiftOutcome.logout),
        ),
      ],
    );

    return next ?? CloseShiftOutcome.logout;
  }
}

class _ShiftClosePanel extends StatelessWidget {
  final ShiftSummary summary;
  final TextEditingController cashController;

  const _ShiftClosePanel({
    required this.summary,
    required this.cashController,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final s = summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.shift.displayLabel,
          style: TextStyle(
            color: AppColors.greyDark,
            fontSize: r.sp(13),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: r.h(12)),
        Container(
          padding: EdgeInsets.all(r.w(14)),
          decoration: BoxDecoration(
            color: AppColors.corporateBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.corporateBlue.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              _summaryRow(r, 'รายการทั้งหมด', '${s.saleCount} รายการ'),
              _summaryRow(
                r,
                'ยอดขายรวม',
                Fmt.money(s.totalSales),
                highlight: true,
              ),
              _summaryRow(r, 'น้ำมัน', '${s.fuelCount} รายการ · ${Fmt.money(s.fuelTotal)}'),
              _summaryRow(
                r,
                'ปริมาณน้ำมัน',
                Fmt.liters(s.liters),
              ),
              if (s.productCount > 0)
                _summaryRow(
                  r,
                  'สินค้า',
                  '${s.productCount} รายการ · ${Fmt.money(s.productTotal)}',
                ),
            ],
          ),
        ),
        if (s.byPayment.isNotEmpty) ...[
          SizedBox(height: r.h(12)),
          Text(
            'แยกตามช่องทางชำระ',
            style: TextStyle(
              color: AppColors.greyDark,
              fontSize: r.sp(12),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.h(6)),
          ...s.byPayment.entries.map(
            (e) => _summaryRow(
              r,
              _paymentLabel(e.key),
              Fmt.money(e.value),
            ),
          ),
        ],
        SizedBox(height: r.h(12)),
        Container(
          padding: EdgeInsets.all(r.w(12)),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _summaryRow(
                r,
                'เงินสดเริ่มต้น',
                Fmt.money(s.shift.openingCash),
              ),
              _summaryRow(r, 'ขายเงินสด', Fmt.money(s.cashSalesTotal)),
              _summaryRow(
                r,
                'เงินในลิ้นชัก (คาดการณ์)',
                Fmt.money(s.expectedDrawerCash),
                highlight: true,
              ),
            ],
          ),
        ),
        SizedBox(height: r.h(14)),
        TextField(
          controller: cashController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'เงินสดในลิ้นชักตอนปิดกะ (บาท)',
            hintText: '0',
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    Responsive r,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(4)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.greyDark,
                fontSize: r.sp(highlight ? 14 : 12),
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.corporateBlueDark : AppColors.black,
              fontSize: r.sp(highlight ? 18 : 13),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String code) {
    for (final m in PaymentMethod.values) {
      if (m.code == code) return m.label;
    }
    return code;
  }
}
