import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/translations.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/responsive.dart';
import '../providers/app_state.dart';
import '../widgets/amount_display.dart';
import '../widgets/custom_keypad.dart';
import '../widgets/glass_card.dart';
import '../widgets/pos_header.dart';
import '../widgets/primary_button.dart';
import 'summary_screen.dart';

class ReceiveAmountScreen extends StatefulWidget {
  const ReceiveAmountScreen({super.key});

  @override
  State<ReceiveAmountScreen> createState() => _ReceiveAmountScreenState();
}

class _ReceiveAmountScreenState extends State<ReceiveAmountScreen> {
  String _raw = '';

  double get _amount => double.tryParse(_raw) ?? 0;

  void _fill(double amount) {
    setState(() => _raw = amount.toStringAsFixed(0));
    TtsService.instance.announceAmount(amount, prefix: T.received);
  }

  void _next(double total) {
    if (_amount < total) {
      TtsService.instance.speak('ยอดเงินรับน้อยกว่ายอดรวมที่ต้องชำระ');
      return;
    }
    context.read<AppState>().setReceivedAmount(_amount);
    final change = _amount - total;
    TtsService.instance.announceAmount(change, prefix: T.change);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SummaryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final total = state.total;
    final change = (_amount - total).clamp(0, double.infinity);

    final quick = {
      total,
      ((total / 100).ceil() * 100).toDouble(),
      ((total / 100).ceil() * 100 + 100).toDouble(),
      ((total / 500).ceil() * 500).toDouble(),
      ((total / 1000).ceil() * 1000).toDouble(),
    }.where((v) => v >= total).toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'รับเงินสด',
        subtitle:
            '${state.fuel?.name ?? ''} • ยอดชำระ ${Fmt.money(total)}',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  padding: EdgeInsets.all(r.w(12)),
                  child: Row(
                    children: [
                      _InfoChip(
                        label: 'ยอดชำระ',
                        value: Fmt.money(total),
                        color: AppColors.corporateBlue,
                      ),
                      SizedBox(width: r.w(8)),
                      _InfoChip(
                        label: 'ลิตร',
                        value: Fmt.liters(state.liters),
                        color: AppColors.fuel91,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.h(12)),
                AmountDisplay(
                  label: 'เงินที่รับ',
                  value: _raw.isEmpty ? '0' : _raw,
                  hint:
                      'เงินทอน ${AppConstants.currencySymbol} ${change.toStringAsFixed(2)}',
                  accent: change > 0 ? AppColors.success : AppColors.corporateBlue,
                  icon: Icons.payments_rounded,
                ),
                SizedBox(height: r.h(12)),
                Text(
                  'เลือกยอดรับด่วน',
                  style: TextStyle(
                    color: AppColors.greyDark,
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: r.h(6)),
                Wrap(
                  spacing: r.w(8),
                  runSpacing: r.h(8),
                  children: quick
                      .take(5)
                      .map(
                        (v) => ActionChip(
                          label: Text(Fmt.money(v)),
                          onPressed: () => _fill(v),
                          backgroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.corporateBlue),
                        ),
                      )
                      .toList(),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'ยืนยันการรับเงิน',
                  icon: Icons.check_circle_rounded,
                  onPressed: () => _next(total),
                ),
              ],
            );

            final keypad = GlassCard(
              padding: EdgeInsets.all(r.w(12)),
              child: CustomKeypad(
                value: _raw,
                onChanged: (v) => setState(() => _raw = v),
                onEnter: (_) => _next(total),
              ),
            );

            return Padding(
              padding: EdgeInsets.all(r.w(16)),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: left),
                        SizedBox(width: r.w(16)),
                        Expanded(flex: 4, child: keypad),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: left),
                        SizedBox(height: r.h(12)),
                        Expanded(child: keypad),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.greyMedium)),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
