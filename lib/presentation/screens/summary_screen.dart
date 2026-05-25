import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/license_features.dart';
import '../../core/i18n/translations.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/fuel_type.dart';
import '../../data/repositories/promotion_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/high_end_dialog.dart';
import '../widgets/pos_header.dart';
import '../widgets/primary_button.dart';
import 'success_screen.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _promoRepo = PromotionRepository();
  final _txRepo = TransactionRepository();
  bool _applying = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoApplyPromotion());
  }

  Future<void> _autoApplyPromotion() async {
    final state = context.read<AppState>();
    if (!state.canUse(AppFeature.promotions)) {
      if (mounted) setState(() => _applying = false);
      return;
    }
    final fuel = state.fuel;
    if (fuel == null) return;
    final promo = await _promoRepo.findApplicable(
      fuelId: fuel.id,
      subtotal: state.subtotal,
      liters: state.liters,
    );
    if (promo != null) {
      final amount = promo.effectiveDiscountAmount(
        subtotal: state.subtotal,
        liters: state.liters,
      );
      state.applyPromotion(promo, amount);
      if (promo.isFreeProduct) {
        TtsService.instance.speak(
            'ใช้โปรโมชั่น ${promo.name} ${promo.freeProductLabel(subtotal: state.subtotal)}');
      } else {
        TtsService.instance.speak(
            'ใช้โปรโมชั่น ${promo.name} แล้ว ประหยัดไป ${amount.toStringAsFixed(2)} บาท');
      }
    }
    if (!mounted) return;
    setState(() => _applying = false);
  }

  Future<void> _editAmount() async {
    final state = context.read<AppState>();
    final controller = TextEditingController(
      text: state.fuelAmount.toStringAsFixed(2),
    );
    final result = await HighEndDialog.show<double>(
      context: context,
      title: T.amount,
      icon: Icons.edit_rounded,
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        style: const TextStyle(
            color: AppColors.black, fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          prefixText: AppConstants.currencySymbol,
          border: UnderlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text(T.cancel, style: TextStyle(color: AppColors.greyMedium)),
        ),
        SizedBox(
          width: 120,
          child: PrimaryButton(
            label: T.confirm,
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
          ),
        ),
      ],
    );
    if (result != null && result > 0) {
      state.setFuelAmount(result);
      setState(() => _applying = true);
      await _autoApplyPromotion();
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final state = context.read<AppState>();

    if (state.shift == null) {
      ToastUtils.show(context, 'กรุณาเปิดกะก่อนทำรายการขาย');
      return;
    }

    final shouldPrint = await HighEndDialog.show<bool>(
      context: context,
      title: 'พิมพ์ใบเสร็จ',
      icon: Icons.print_rounded,
      maxWidth: 360,
      message: 'ต้องการพิมพ์ใบเสร็จสำหรับรายการนี้หรือไม่?',
      actions: [
        PrimaryButton(
          label: 'พิมพ์ใบเสร็จ',
          icon: Icons.print_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
        PrimaryButton(
          label: 'ไม่พิมพ์',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );
    if (shouldPrint == null) return;
    state.setPrintRequested(shouldPrint);

    setState(() => _saving = true);
    final fuel = state.fuel!;
    try {
      final tx = await _txRepo.create(
        cashierId: state.user!.id,
        shiftId: state.shift?.id,
        fuelTypeId: fuel.id,
        dispenserId: state.selectedDispenser?.id,
        nozzleId: state.selectedNozzle?['id'],
        paymentMethod: state.paymentMethod!.code,
        liters: state.liters,
        pricePerLiter: fuel.pricePerLiter,
        subtotal: state.subtotal,
        promotionId: state.promotion?.id,
        promotionAmount: state.promotionAmount,
        discountId: state.discountId,
        discountAmount: state.discountAmount,
        total: state.total,
        received: state.receivedAmount,
        changeAmount: state.change,
        customerId: state.selectedCustomer?.id,
        notes: _buildTransactionNotes(state),
        rewardProductId: state.promotion?.isFreeProduct == true
            ? state.promotion!.rewardProductId
            : null,
        rewardQty: state.promotion?.isFreeProduct == true
            ? state.promotion!.computedRewardQty(state.subtotal)
            : 0,
      );

    bool printed = false;
    if (shouldPrint) {
      printed = await BluetoothPrinterService.instance.printReceipt(
        tx: tx,
        fuelName: fuel.name,
        cashierName: state.user!.displayName ?? state.user!.username,
        customer: state.selectedCustomer,
        promotion: state.promotion,
      );
      if (printed) await _txRepo.markPrinted(tx.id);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          transaction: tx,
          printed: printed,
          printRequested: shouldPrint,
        ),
      ),
    );
    } on StockInsufficientException catch (e) {
      if (mounted) {
        ToastUtils.show(context, e.toString());
        setState(() => _saving = false);
      }
    } on ShiftRequiredException catch (e) {
      if (mounted) {
        ToastUtils.show(context, e.toString());
        setState(() => _saving = false);
      }
    } on TankStockInsufficientException catch (e) {
      if (mounted) {
        ToastUtils.show(context, e.toString());
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'บันทึกรายการไม่สำเร็จ กรุณาลองใหม่');
        setState(() => _saving = false);
      }
    }
  }

  void _cancel() {
    context.read<AppState>().resetTransaction();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String? _buildTransactionNotes(AppState state) {
    final parts = <String>[];
    final tax = state.selectedCustomer?.formatTaxNotes();
    if (tax != null && tax.isNotEmpty) parts.add(tax);
    final promoNote =
        state.promotion?.promotionNoteLine(subtotal: state.subtotal);
    if (promoNote != null) parts.add(promoNote);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  Widget _buildSummaryPanel(
    Responsive r,
    AppState state,
    FuelType? fuel,
  ) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(20)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    color: AppColors.corporateBlue, size: r.sp(36)),
                SizedBox(width: r.w(12)),
                Expanded(
                  child: Text(
                    'สรุปยอดชำระเงิน',
                    style: TextStyle(
                      color: AppColors.corporateBlueDark,
                      fontSize: r.sp(20),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: AppColors.greyLight, height: r.h(24)),
            _Row(label: T.fuel, value: fuel?.name ?? '-', big: true),
            _Row(label: T.liters, value: Fmt.liters(state.liters)),
            _Row(
              label: '${T.price} / ${T.liters}',
              value: Fmt.money(fuel?.pricePerLiter ?? 0),
            ),
            SizedBox(height: r.h(8)),
            _Row(
              label: T.amount,
              value: Fmt.money(state.subtotal),
              trailing: IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: AppColors.corporateBlue, size: 20),
                onPressed: _saving ? null : _editAmount,
              ),
            ),
            if (state.promotion != null)
              _Row(
                label: 'โปรโมชั่น (${state.promotion!.name})',
                value: state.promotion!.isFreeProduct
                    ? state.promotion!
                        .freeProductLabel(subtotal: state.subtotal)
                    : '-${Fmt.money(state.promotionAmount)}',
                valueColor: AppColors.success,
              ),
            if (state.discountAmount > 0)
              _Row(
                label: T.discount,
                value: '-${Fmt.money(state.discountAmount)}',
                valueColor: AppColors.success,
              ),
            SizedBox(height: r.h(12)),
            Container(
              padding: EdgeInsets.all(r.w(16)),
              decoration: BoxDecoration(
                color: AppColors.corporateBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.corporateBlue.withValues(alpha: 0.15),
                ),
              ),
              child: _Row(
                label: T.total,
                value: Fmt.money(state.total),
                big: true,
                valueColor: AppColors.corporateBlue,
              ),
            ),
            if (state.paymentMethod?.requiresChange ?? false) ...[
              SizedBox(height: r.h(12)),
              _Row(
                label: T.received,
                value: Fmt.money(state.receivedAmount),
                valueColor: AppColors.greyDark,
              ),
              _Row(
                label: T.change,
                value: Fmt.money(state.change),
                valueColor: AppColors.success,
                big: true,
              ),
            ],
            if (_applying)
              Padding(
                padding: EdgeInsets.only(top: r.h(12)),
                child: const LinearProgressIndicator(
                  color: AppColors.corporateBlue,
                  backgroundColor: AppColors.greyLight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(Responsive r, AppState state) {
    return GlassCard(
      padding: EdgeInsets.all(r.w(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ยอดชำระ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.greyMedium,
              fontSize: r.sp(13),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.h(4)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Fmt.money(state.total),
              style: TextStyle(
                color: AppColors.corporateBlue,
                fontSize: r.sp(36),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (state.paymentMethod != null) ...[
            SizedBox(height: r.h(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.w(12),
                vertical: r.h(6),
              ),
              decoration: BoxDecoration(
                color: AppColors.corporateBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                state.paymentMethod!.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.corporateBlueDark,
                  fontWeight: FontWeight.w700,
                  fontSize: r.sp(13),
                ),
              ),
            ),
          ],
          const Spacer(),
          PrimaryButton(
            label: T.confirm,
            icon: Icons.check_circle_rounded,
            loading: _saving,
            onPressed: _saving ? null : _confirm,
          ),
          SizedBox(height: r.h(12)),
          PrimaryButton(
            label: T.cancel,
            variant: ButtonVariant.outline,
            onPressed: _saving ? null : _cancel,
          ),
          SizedBox(height: r.h(8)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final fuel = state.fuel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'สรุปรายการ',
        subtitle: state.paymentMethod?.label,
        onBack: _saving ? null : () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useSideBySide = constraints.maxWidth >= 520;

            final summary = _buildSummaryPanel(r, state, fuel);
            final actions = _buildActionPanel(r, state);

            return Padding(
              padding: EdgeInsets.all(r.w(16)),
              child: useSideBySide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: summary),
                        SizedBox(width: r.w(16)),
                        SizedBox(
                          width: constraints.maxWidth * 0.32,
                          child: actions,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: summary),
                        SizedBox(height: r.h(12)),
                        actions,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final Color? valueColor;
  final Widget? trailing;
  const _Row(
      {required this.label,
      required this.value,
      this.big = false,
      this.valueColor,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(8)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: AppColors.greyDark,
                  fontSize: big ? r.sp(18) : r.sp(15),
                  fontWeight: big ? FontWeight.w800 : FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
                color: valueColor ?? AppColors.black,
                fontSize: big ? r.sp(26) : r.sp(18),
                fontWeight: FontWeight.w900),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
