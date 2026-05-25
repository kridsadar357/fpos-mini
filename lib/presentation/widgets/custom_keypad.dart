import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/responsive.dart';

/// On-screen numeric keypad for POS — replaces system keyboard.
/// Big tap targets (>= 64px), haptic + TTS feedback, capped to 10 chars.
class CustomKeypad extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onEnter;
  final bool allowDecimal;
  final int maxLength;
  final bool speakDigits;

  const CustomKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    this.onEnter,
    this.allowDecimal = true,
    this.maxLength = 10,
    this.speakDigits = true,
  });

  @override
  State<CustomKeypad> createState() => _CustomKeypadState();
}

class _CustomKeypadState extends State<CustomKeypad> {
  void _append(String digit) {
    HapticFeedback.selectionClick();
    String next = widget.value;
    if (digit == '.') {
      if (!widget.allowDecimal) return;
      if (next.contains('.')) return;
      next = next.isEmpty ? '0.' : '$next.';
    } else {
      if (next == '0') {
        next = digit;
      } else {
        next = '$next$digit';
      }
    }
    if (next.length > widget.maxLength) return;
    widget.onChanged(next);
    if (widget.speakDigits) TtsService.instance.announceDigit(digit);
  }

  void _backspace() {
    HapticFeedback.lightImpact();
    if (widget.value.isEmpty) return;
    final next = widget.value.substring(0, widget.value.length - 1);
    widget.onChanged(next);
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    widget.onChanged('');
  }

  void _enter() {
    HapticFeedback.heavyImpact();
    widget.onEnter?.call(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      widget.allowDecimal ? '.' : 'C', '0', '⌫',
    ];

    return Container(
      padding: EdgeInsets.all(r.w(8)),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(r.r(20)),
        border: Border.all(color: AppColors.goldDark, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: r.h(8),
            crossAxisSpacing: r.w(8),
            childAspectRatio: 1.6,
            children: keys.map((k) => _KeyButton(
              label: k,
              onTap: () {
                if (k == '⌫') {
                  _backspace();
                } else if (k == 'C') {
                  _clear();
                } else {
                  _append(k);
                }
              },
              color: k == '⌫' || k == 'C' ? AppColors.red : AppColors.surfaceAlt,
              textColor: k == '⌫' || k == 'C' ? AppColors.white : AppColors.gold,
            )).toList(),
          ),
          SizedBox(height: r.h(8)),
          if (widget.onEnter != null)
            SizedBox(
              width: double.infinity,
              child: _KeyButton(
                label: 'ENTER',
                onTap: _enter,
                color: AppColors.gold,
                textColor: AppColors.black,
                fontSize: r.sp(22),
                height: r.h(64),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final double? fontSize;
  final double? height;

  const _KeyButton({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
    this.fontSize,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(r.r(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(r.r(12)),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize ?? r.sp(28),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
