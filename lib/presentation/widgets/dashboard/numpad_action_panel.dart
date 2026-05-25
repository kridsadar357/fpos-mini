import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../providers/app_state.dart';
import '../glass_card.dart';

class NumpadActionPanel extends StatelessWidget {
  final VoidCallback onPay;
  final VoidCallback onSuspend;
  final VoidCallback onCancel;
  final VoidCallback onFleetCard;
  final VoidCallback? onSuspendedList;

  const NumpadActionPanel({
    super.key,
    required this.onPay,
    required this.onSuspend,
    required this.onCancel,
    required this.onFleetCard,
    this.onSuspendedList,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return GlassCard(
      padding: EdgeInsets.all(r.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ตัวเลข/ฟลีท',
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onSuspendedList != null)
                TextButton(
                  onPressed: onSuspendedList,
                  child: Text('พักไว้',
                      style: TextStyle(fontSize: r.sp(11))),
                ),
              TextButton(
                onPressed: onFleetCard,
                child: Text('บัตรฟลีท',
                    style: TextStyle(fontSize: r.sp(11))),
              ),
            ],
          ),
          Divider(color: AppColors.greyLight, height: r.h(16)),
          const Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _NumBtn('7'),
                      _NumBtn('8'),
                      _NumBtn('9'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _NumBtn('4'),
                      _NumBtn('5'),
                      _NumBtn('6'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _NumBtn('1'),
                      _NumBtn('2'),
                      _NumBtn('3'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _NumBtn('.'),
                      _NumBtn('0'),
                      _NumBtn('BACK',
                          isIcon: true,
                          icon: Icons.backspace_rounded,
                          color: AppColors.corporateBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumBtn extends StatelessWidget {
  final String char;
  final bool isIcon;
  final IconData? icon;
  final Color? color;

  const _NumBtn(this.char, {this.isIcon = false, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => context.read<AppState>().appendInput(char),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.greyLight, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isIcon
                  ? Icon(icon, color: color, size: r.sp(20))
                  : Text(char,
                      style: TextStyle(
                          color: AppColors.black,
                          fontSize: r.sp(18),
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
