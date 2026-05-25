import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/license_features.dart';
import '../../../../core/utils/formatter.dart';
import '../../../../core/utils/fuel_color_util.dart'
    show fuelColorForName, shortFuelLabel;
import '../../../../core/utils/responsive.dart';
import '../../../../data/repositories/promotion_repository.dart';
import '../../providers/app_state.dart';
import '../glass_card.dart';

class SaleEntryPanel extends StatefulWidget {
  final VoidCallback onPay;
  final VoidCallback onSuspend;
  final VoidCallback onCancel;
  final VoidCallback onPrint;
  final VoidCallback onSelectCustomer;

  const SaleEntryPanel({
    super.key,
    required this.onPay,
    required this.onSuspend,
    required this.onCancel,
    required this.onPrint,
    required this.onSelectCustomer,
  });

  @override
  State<SaleEntryPanel> createState() => _SaleEntryPanelState();
}

class _SaleEntryPanelState extends State<SaleEntryPanel> {
  final _promoRepo = PromotionRepository();
  AppState? _state;
  bool _applyingPromo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _state = context.read<AppState>();
      _state!.addListener(_schedulePromotionApply);
      _applyPromotion();
    });
  }

  @override
  void dispose() {
    _state?.removeListener(_schedulePromotionApply);
    super.dispose();
  }

  void _schedulePromotionApply() {
    if (!mounted || _applyingPromo) return;
    _applyPromotion();
  }

  Future<void> _applyPromotion() async {
    if (!mounted || _state == null) return;
    final state = _state!;
    if (_applyingPromo) return;

    if (!state.canUse(AppFeature.promotions) || state.fuel == null || state.subtotal <= 0) {
      if (state.promotion != null) {
        state.applyPromotion(null, 0);
      }
      return;
    }

    _applyingPromo = true;
    try {
      final promo = await _promoRepo.findApplicable(
        fuelId: state.fuel!.id,
        subtotal: state.subtotal,
        liters: state.liters,
      );
      if (!mounted) return;

      if (promo == null) {
        if (state.promotion != null) state.applyPromotion(null, 0);
        return;
      }

      final amount = promo.effectiveDiscountAmount(
        subtotal: state.subtotal,
        liters: state.liters,
      );
      if (state.promotion?.id == promo.id &&
          state.promotionAmount == amount) {
        return;
      }
      state.applyPromotion(promo, amount);
    } finally {
      _applyingPromo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;

        return GlassCard(
          padding: EdgeInsets.all(r.w(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ทำรายการขาย',
                style: TextStyle(
                  color: AppColors.corporateBlueDark,
                  fontSize: r.sp(14),
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: r.h(6)),
              _SelectedFuelBar(state: state),
              SizedBox(height: r.h(6)),
              Row(
                children: [
                  Expanded(
                    child: _InputBox(
                      label: 'จำนวน (บาท)',
                      value: state.inputtingLiters
                          ? (state.subtotal > 0
                              ? state.subtotal.toStringAsFixed(2)
                              : '0')
                          : (state.rawInput.isEmpty
                              ? '0'
                              : state.rawInput),
                      onTap: () => state.toggleInputMode(false),
                      isActive: !state.inputtingLiters,
                    ),
                  ),
                  SizedBox(width: r.w(8)),
                  Expanded(
                    child: _InputBox(
                      label: 'จำนวน (ลิตร)',
                      value: state.inputtingLiters
                          ? (state.rawInput.isEmpty
                              ? '0'
                              : state.rawInput)
                          : (state.liters > 0
                              ? state.liters.toStringAsFixed(2)
                              : '0.00'),
                      onTap: () => state.toggleInputMode(true),
                      isActive: state.inputtingLiters,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(6)),
              InkWell(
                onTap: widget.onSelectCustomer,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.w(8),
                    vertical: r.h(6),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: state.selectedCustomer == null
                          ? AppColors.greyLight
                          : AppColors.corporateBlue,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.selectedCustomer?.isCompany == true
                            ? Icons.business_rounded
                            : Icons.person_outline_rounded,
                        color: AppColors.corporateBlue,
                        size: r.sp(18),
                      ),
                      SizedBox(width: r.w(6)),
                      Expanded(
                        child: Text(
                          state.selectedCustomer == null
                              ? 'เลือกลูกค้า / เพิ่มลูกค้า'
                              : state.selectedCustomer!.displayLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: state.selectedCustomer == null
                                ? AppColors.greyMedium
                                : AppColors.corporateBlueDark,
                            fontSize: r.sp(12),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (state.selectedCustomer != null)
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.greyMedium, size: r.sp(18)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: r.h(8)),
              Expanded(
                child: _SaleBody(state: state),
              ),
              SizedBox(height: r.h(8)),
              _ActionButtons(
                narrow: narrow,
                onPay: widget.onPay,
                onSuspend: widget.onSuspend,
                onCancel: widget.onCancel,
                onPrint: widget.onPrint,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SaleBody extends StatelessWidget {
  final AppState state;

  const _SaleBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final fuel = state.fuel;
    final hasFuel = fuel != null;
    final accent = hasFuel
        ? fuelColorForName(fuel.name)
        : AppColors.corporateBlue;

    return Container(
      padding: EdgeInsets.all(r.w(10)),
      decoration: BoxDecoration(
        color: AppColors.corporateBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.corporateBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: hasFuel
                  ? _AmountHero(state: state, accent: accent)
                  : Text(
                      'เลือกมือจ่าย\nแล้วกรอกยอด',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.greyMedium,
                        fontSize: r.sp(13),
                      ),
                    ),
            ),
          ),
          if (hasFuel) ...[
            Divider(color: AppColors.greyLight, height: r.h(12)),
            _SummaryBlock(state: state),
            SizedBox(height: r.h(8)),
            _QuickAmountRow(state: state),
          ],
        ],
      ),
    );
  }
}

class _AmountHero extends StatelessWidget {
  final AppState state;
  final Color accent;

  const _AmountHero({required this.state, required this.accent});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final isLiters = state.inputtingLiters;
    final main = isLiters
        ? state.liters.toStringAsFixed(2)
        : Fmt.moneyPlain(state.subtotal);
    final unit = isLiters ? 'ลิตร' : 'บาท';
    final sub = isLiters
        ? Fmt.money(state.subtotal)
        : '≈ ${state.liters.toStringAsFixed(2)} ลิตร';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isLiters ? 'กำลังกรอก (ลิตร)' : 'กำลังกรอก (บาท)',
          style: TextStyle(
            color: AppColors.greyMedium,
            fontSize: r.sp(11),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: r.h(4)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            main,
            style: TextStyle(
              color: accent,
              fontSize: r.sp(42),
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            color: AppColors.corporateBlueDark,
            fontSize: r.sp(14),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.h(4)),
        Text(
          sub,
          style: TextStyle(
            color: AppColors.greyDark,
            fontSize: r.sp(12),
          ),
        ),
      ],
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final AppState state;

  const _SummaryBlock({required this.state});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final fuel = state.fuel!;

    return Column(
      children: [
        _summaryRow(
          r,
          'ราคา / ลิตร',
          Fmt.money(fuel.pricePerLiter),
        ),
        _summaryRow(r, 'ลิตร', Fmt.liters(state.liters)),
        if (state.promotion != null)
          _summaryRow(
            r,
            'โปรโมชั่น (${state.promotion!.name})',
            state.promotion!.isFreeProduct
                ? state.promotion!.freeProductLabel(subtotal: state.subtotal)
                : '-${Fmt.money(state.promotionAmount)}',
            valueColor: AppColors.success,
          )
        else if (state.promotionAmount > 0)
          _summaryRow(
            r,
            'โปรโมชั่น',
            '-${Fmt.money(state.promotionAmount)}',
            valueColor: AppColors.success,
          ),
        if (state.discountAmount > 0)
          _summaryRow(
            r,
            'ส่วนลด',
            '-${Fmt.money(state.discountAmount)}',
            valueColor: AppColors.success,
          ),
        SizedBox(height: r.h(4)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.w(10),
            vertical: r.h(8),
          ),
          decoration: BoxDecoration(
            color: AppColors.corporateBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _summaryRow(
            r,
            'ยอดรวม',
            Fmt.money(state.total),
            big: true,
            valueColor: AppColors.corporateBlue,
          ),
        ),
      ],
    );
  }

  static Widget _summaryRow(
    Responsive r,
    String label,
    String value, {
    bool big = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(2)),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.greyDark,
              fontSize: r.sp(big ? 13 : 11),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.corporateBlueDark,
              fontSize: r.sp(big ? 16 : 12),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountRow extends StatelessWidget {
  final AppState state;

  const _QuickAmountRow({required this.state});

  static const _amounts = [100.0, 200.0, 300.0, 500.0, 1000.0];

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ยอดด่วน (บาท)',
          style: TextStyle(
            color: AppColors.greyMedium,
            fontSize: r.sp(10),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: r.h(4)),
        Wrap(
          spacing: r.w(6),
          runSpacing: r.h(6),
          children: [
            for (final a in _amounts)
              _QuickChip(
                label: a >= 1000 ? '1k' : '${a.toInt()}',
                onTap: state.fuel == null
                    ? null
                    : () => state.setQuickBaht(a),
              ),
            _QuickChip(
              label: 'ล้าง',
              outline: true,
              onTap: () => state.appendInput('CLEAR'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outline;

  const _QuickChip({
    required this.label,
    this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outline ? AppColors.white : AppColors.corporateBlue,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: outline
                  ? AppColors.greyLight
                  : AppColors.corporateBlue,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: outline ? AppColors.greyDark : AppColors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool narrow;
  final VoidCallback onPay;
  final VoidCallback onSuspend;
  final VoidCallback onCancel;
  final VoidCallback onPrint;

  const _ActionButtons({
    required this.narrow,
    required this.onPay,
    required this.onSuspend,
    required this.onCancel,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    Widget btn(String label, Color color, VoidCallback onTap) {
      return _LargeActionBtn(label: label, color: color, onTap: onTap);
    }

    if (narrow) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: btn('ชำระเงิน', AppColors.success, onPay)),
              SizedBox(width: r.w(6)),
              Expanded(child: btn('พักบิล', AppColors.corporateBlue, onSuspend)),
            ],
          ),
          SizedBox(height: r.h(6)),
          Row(
            children: [
              Expanded(child: btn('ยกเลิก', AppColors.danger, onCancel)),
              SizedBox(width: r.w(6)),
              Expanded(
                  child: btn('พิมพ์ใบเสร็จ', AppColors.corporateBlue, onPrint)),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: btn('ชำระเงิน', AppColors.success, onPay)),
        SizedBox(width: r.w(6)),
        Expanded(child: btn('พักบิล', AppColors.corporateBlue, onSuspend)),
        SizedBox(width: r.w(6)),
        Expanded(child: btn('ยกเลิก', AppColors.danger, onCancel)),
        SizedBox(width: r.w(6)),
        Expanded(child: btn('พิมพ์', AppColors.corporateBlue, onPrint)),
      ],
    );
  }
}

class _LargeActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LargeActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: r.h(42).clamp(36.0, 48.0),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: r.sp(13),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedFuelBar extends StatelessWidget {
  final AppState state;

  const _SelectedFuelBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final fuel = state.fuel;
    if (fuel == null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(6)),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'เลือกมือจ่ายจากแผงซ้าย',
          style: TextStyle(color: AppColors.greyMedium, fontSize: r.sp(11)),
        ),
      );
    }
    final color = fuelColorForName(fuel.name);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(5)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(10),
            height: r.w(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: r.w(6)),
          Expanded(
            child: Text(
              shortFuelLabel(fuel.name),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: r.sp(12),
                color: AppColors.corporateBlueDark,
              ),
            ),
          ),
          Text(
            '${fuel.pricePerLiter.toStringAsFixed(2)} /L',
            style: TextStyle(
              fontSize: r.sp(11),
              fontWeight: FontWeight.w700,
              color: AppColors.greyDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isActive;

  const _InputBox({
    required this.label,
    required this.value,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.greyDark,
            fontSize: r.sp(11),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.corporateBlue : AppColors.greyLight,
                width: isActive ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: isActive ? AppColors.black : AppColors.greyMedium,
                  fontSize: r.sp(16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
