import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/i18n/translations.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/fuel_color_util.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/promotion.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/promotion_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/pos_header.dart';
import '../widgets/primary_button.dart';
import 'pos_dashboard_screen.dart';

class SuccessScreen extends StatefulWidget {
  final Transaction transaction;
  final bool printed;
  final bool printRequested;

  const SuccessScreen({
    super.key,
    required this.transaction,
    required this.printed,
    required this.printRequested,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _ParsedCustomerNotes {
  String? name;
  String? taxId;
  String? branch;
  String? address;
  String? postalCode;
  String? phone;
  String? email;
  String? contact;
  String? plate;
  String? fleet;
  final List<String> extras = [];

  bool get hasTaxData =>
      (name != null && name!.isNotEmpty) ||
      (taxId != null && taxId!.isNotEmpty);

  static _ParsedCustomerNotes parse(String notes) {
    final out = _ParsedCustomerNotes();
    for (final raw in notes.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final i = line.indexOf(':');
      if (i <= 0) {
        out.extras.add(line);
        continue;
      }
      final key = line.substring(0, i).trim();
      final val = line.substring(i + 1).trim();
      switch (key) {
        case 'ลูกค้า':
          out.name = val;
        case 'เลขผู้เสียภาษี':
          out.taxId = val;
        case 'สาขา':
          out.branch = val;
        case 'ที่อยู่':
          out.address = val;
        case 'รหัสไปรษณีย์':
          out.postalCode = val;
        case 'โทร':
          out.phone = val;
        case 'อีเมล':
          out.email = val;
        case 'ผู้ติดต่อ':
          out.contact = val;
        case 'ทะเบียนรถ':
          out.plate = val;
        case 'บัตรฟลีท':
          out.fleet = val;
        default:
          out.extras.add(line);
      }
    }
    return out;
  }
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _retrying = false;
  String? _fuelName;
  Promotion? _promotion;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadFuelName();
    _loadPromotion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.instance.speak(
        'ทำรายการสำเร็จ เงินทอน ${widget.transaction.changeAmount.toStringAsFixed(2)} บาท',
      );
    });
  }

  Future<void> _loadPromotion() async {
    final id = widget.transaction.promotionId;
    if (id == null) return;
    final promo = await PromotionRepository().getById(id);
    if (!mounted) return;
    setState(() => _promotion = promo);
  }

  Future<void> _loadFuelName() async {
    final fuel =
        await FuelRepository().getById(widget.transaction.fuelTypeId);
    if (!mounted) return;
    setState(() => _fuelName = fuel?.name);
  }

  String? _promotionRewardLabel(Transaction tx) {
    if (tx.rewardQty > 0) {
      final name = _promotion?.rewardProductName ?? 'สินค้า';
      return tx.rewardQty > 1 ? 'แถม$name x${tx.rewardQty}' : 'แถม$name';
    }
    if (_promotion != null) {
      if (_promotion!.isFreeProduct) {
        return _promotion!.freeProductLabel(subtotal: tx.subtotal);
      }
      return '-${Fmt.money(tx.promotionAmount)}';
    }
    if (tx.promotionAmount > 0) {
      return '-${Fmt.money(tx.promotionAmount)}';
    }
    return null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _retryPrint() async {
    if (_retrying) return;
    final state = context.read<AppState>();
    setState(() => _retrying = true);
    final fuel = await FuelRepository().getById(widget.transaction.fuelTypeId);
    final ok = await BluetoothPrinterService.instance.printReceipt(
      tx: widget.transaction,
      fuelName: fuel?.name ?? 'น้ำมัน',
      cashierName: state.user?.displayName ?? state.user?.username ?? '',
      promotion: _promotion,
    );
    if (ok) await TransactionRepository().markPrinted(widget.transaction.id);
    if (!mounted) return;
    setState(() => _retrying = false);
    ToastUtils.show(
      context,
      ok ? 'พิมพ์สำเร็จ' : 'พิมพ์ไม่สำเร็จ — ตรวจสอบ Bluetooth (ลอง ${BluetoothPrinterService.maxPrintAttempts} ครั้งแล้ว)',
    );
  }

  void _newTransaction() {
    context.read<AppState>().resetTransaction();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PosDashboardScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final tx = widget.transaction;
    final state = context.watch<AppState>();
    final cashier =
        state.user?.displayName ?? state.user?.username ?? '-';
    final timeStr =
        DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt.toLocal());
    final fuelLabel = _fuelName ?? '—';
    final customer = tx.notes != null && tx.notes!.trim().isNotEmpty
        ? _ParsedCustomerNotes.parse(tx.notes!.trim())
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'สำเร็จ',
        subtitle: tx.receiptNo,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final threeCol = constraints.maxWidth >= 900;
            final twoCol = constraints.maxWidth >= 640;
            final padH = r.w(8);
            final padV = r.h(6);
            final cardH = constraints.maxHeight - padV * 2;

            return Padding(
              padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
              child: SizedBox(
                height: cardH,
                width: constraints.maxWidth,
                child: GlassCard(
                  padding: EdgeInsets.all(r.w(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSuccessBanner(r, tx, timeStr),
                      SizedBox(height: r.h(8)),
                      Expanded(
                        child: threeCol
                            ? _threeColumnBody(
                                r,
                                tx,
                                fuelLabel: fuelLabel,
                                cashier: cashier,
                                customer: customer,
                              )
                            : twoCol
                                ? _twoColumnBody(
                                    r,
                                    tx,
                                    fuelLabel: fuelLabel,
                                    cashier: cashier,
                                    customer: customer,
                                  )
                                : _singleColumnBody(
                                    r,
                                    tx,
                                    fuelLabel: fuelLabel,
                                    cashier: cashier,
                                    customer: customer,
                                  ),
                      ),
                      SizedBox(height: r.h(8)),
                      _buildActions(r, twoCol),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _threeColumnBody(
    Responsive r,
    Transaction tx, {
    required String fuelLabel,
    required String cashier,
    required _ParsedCustomerNotes? customer,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _salePanel(r, tx, fuelLabel: fuelLabel),
        ),
        SizedBox(width: r.w(8)),
        Expanded(
          flex: 3,
          child: _paymentPanel(r, tx, cashier: cashier),
        ),
        if (customer != null && customer.hasTaxData) ...[
          SizedBox(width: r.w(8)),
          Expanded(
            flex: 4,
            child: _customerPanel(r, customer),
          ),
        ],
      ],
    );
  }

  Widget _twoColumnBody(
    Responsive r,
    Transaction tx, {
    required String fuelLabel,
    required String cashier,
    required _ParsedCustomerNotes? customer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: customer != null && customer.hasTaxData ? 3 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _salePanel(r, tx, fuelLabel: fuelLabel),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                child: _paymentPanel(r, tx, cashier: cashier),
              ),
            ],
          ),
        ),
        if (customer != null && customer.hasTaxData) ...[
          SizedBox(height: r.h(8)),
          Expanded(
            flex: 2,
            child: _customerPanel(r, customer),
          ),
        ],
      ],
    );
  }

  Widget _singleColumnBody(
    Responsive r,
    Transaction tx, {
    required String fuelLabel,
    required String cashier,
    required _ParsedCustomerNotes? customer,
  }) {
    final hasCustomer = customer != null && customer.hasTaxData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: hasCustomer ? 3 : 4,
          child: _salePanel(r, tx, fuelLabel: fuelLabel),
        ),
        SizedBox(height: r.h(8)),
        Expanded(
          flex: hasCustomer ? 2 : 3,
          child: _paymentPanel(r, tx, cashier: cashier),
        ),
        if (hasCustomer) ...[
          SizedBox(height: r.h(8)),
          Expanded(
            flex: 3,
            child: _customerPanel(r, customer),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessBanner(
    Responsive r,
    Transaction tx,
    String timeStr,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(10),
        vertical: r.h(8),
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
            child: Container(
              width: r.w(40),
              height: r.w(40),
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  color: AppColors.white, size: r.sp(24)),
            ),
          ),
          SizedBox(width: r.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ทำรายการสำเร็จ',
                  style: TextStyle(
                    color: AppColors.corporateBlueDark,
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$timeStr  ·  ${tx.receiptNo}',
                  style: TextStyle(
                    color: AppColors.greyMedium,
                    fontSize: r.sp(10),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.w(12),
              vertical: r.h(6),
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.greyLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  T.total,
                  style: TextStyle(
                    color: AppColors.greyMedium,
                    fontSize: r.sp(9),
                  ),
                ),
                Text(
                  Fmt.money(tx.total),
                  style: TextStyle(
                    color: AppColors.corporateBlue,
                    fontSize: r.sp(20),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelShell(
    Responsive r, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greyLight),
      ),
      padding: EdgeInsets.all(r.w(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: r.sp(14), color: AppColors.corporateBlue),
              SizedBox(width: r.w(4)),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.corporateBlueDark,
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(8)),
          Expanded(
            child: SingleChildScrollView(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _salePanel(
    Responsive r,
    Transaction tx, {
    required String fuelLabel,
  }) {
    final fuelColor = fuelColorForName(fuelLabel);
    final promoText = _promotionRewardLabel(tx);

    return _panelShell(
      r,
      icon: Icons.local_gas_station_rounded,
      title: 'รายการขาย',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(r.w(10)),
            decoration: BoxDecoration(
              color: fuelColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: fuelColor, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fuelLabel,
                  style: TextStyle(
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.w900,
                    color: AppColors.corporateBlueDark,
                  ),
                ),
                SizedBox(height: r.h(6)),
                Wrap(
                  spacing: r.w(6),
                  runSpacing: r.h(4),
                  children: [
                    _statChip(r, T.liters, Fmt.liters(tx.liters)),
                    _statChip(
                      r,
                      '${T.price}/${T.liters}',
                      Fmt.money(tx.pricePerLiter),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(8)),
          _amountLine(r, T.amount, Fmt.money(tx.subtotal)),
          if (promoText != null) ...[
            SizedBox(height: r.h(4)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.w(8),
                vertical: r.h(5),
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      size: r.sp(14), color: AppColors.success),
                  SizedBox(width: r.w(6)),
                  Expanded(
                    child: Text(
                      _promotion?.name ?? 'โปรโมชั่น',
                      style: TextStyle(
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  Text(
                    promoText,
                    style: TextStyle(
                      fontSize: r.sp(10),
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tx.discountAmount > 0) ...[
            SizedBox(height: r.h(4)),
            _amountLine(
              r,
              T.discount,
              '-${Fmt.money(tx.discountAmount)}',
              valueColor: AppColors.success,
            ),
          ],
          SizedBox(height: r.h(8)),
          const Divider(color: AppColors.greyLight, height: 1),
          SizedBox(height: r.h(6)),
          _amountLine(
            r,
            T.total,
            Fmt.money(tx.total),
            bold: true,
            valueColor: AppColors.corporateBlue,
          ),
        ],
      ),
    );
  }

  Widget _paymentPanel(
    Responsive r,
    Transaction tx, {
    required String cashier,
  }) {
    final printLabel = widget.printRequested
        ? (widget.printed ? 'พิมพ์แล้ว' : 'พิมพ์ไม่สำเร็จ')
        : 'ไม่พิมพ์';
    final printColor = widget.printRequested && !widget.printed
        ? AppColors.danger
        : widget.printed
            ? AppColors.success
            : AppColors.greyMedium;

    return _panelShell(
      r,
      icon: Icons.payments_rounded,
      title: 'การชำระเงิน',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _badge(r, _paymentLabel(tx.paymentMethod), AppColors.corporateBlue),
          SizedBox(height: r.h(8)),
          if (tx.received > 0)
            Row(
              children: [
                Expanded(
                  child: _moneyBox(
                    r,
                    label: T.received,
                    value: Fmt.money(tx.received),
                  ),
                ),
                SizedBox(width: r.w(6)),
                Expanded(
                  child: _moneyBox(
                    r,
                    label: T.change,
                    value: Fmt.money(tx.changeAmount),
                    highlight: true,
                  ),
                ),
              ],
            ),
          SizedBox(height: r.h(8)),
          _infoLine(r, Icons.person_outline_rounded, 'แคชเชียร์', cashier),
          SizedBox(height: r.h(4)),
          _infoLine(
            r,
            Icons.print_rounded,
            'ใบเสร็จ',
            printLabel,
            valueColor: printColor,
          ),
        ],
      ),
    );
  }

  Widget _customerPanel(Responsive r, _ParsedCustomerNotes c) {
    return _panelShell(
      r,
      icon: Icons.receipt_long_rounded,
      title: 'ลูกค้า / ใบกำกับภาษี',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.name != null)
            Text(
              c.name!,
              style: TextStyle(
                fontSize: r.sp(12),
                fontWeight: FontWeight.w900,
                color: AppColors.corporateBlueDark,
              ),
            ),
          if (c.taxId != null) ...[
            SizedBox(height: r.h(4)),
            Wrap(
              spacing: r.w(8),
              runSpacing: r.h(2),
              children: [
                _miniTag(r, 'Tax ${c.taxId}'),
                if (c.branch != null) _miniTag(r, 'สาขา ${c.branch}'),
              ],
            ),
          ],
          if (c.address != null) ...[
            SizedBox(height: r.h(6)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.w(8)),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.greyLight),
              ),
              child: Text(
                [
                  c.address,
                  if (c.postalCode != null) c.postalCode,
                ].join(' '),
                style: TextStyle(
                  fontSize: r.sp(10),
                  color: AppColors.greyDark,
                  height: 1.35,
                ),
              ),
            ),
          ],
          SizedBox(height: r.h(6)),
          if (c.phone != null)
            _infoLine(r, Icons.phone_outlined, 'โทร', c.phone!),
          if (c.email != null)
            _infoLine(r, Icons.email_outlined, 'อีเมล', c.email!),
          if (c.contact != null)
            _infoLine(r, Icons.badge_outlined, 'ผู้ติดต่อ', c.contact!),
          if (c.plate != null || c.fleet != null) ...[
            SizedBox(height: r.h(4)),
            Wrap(
              spacing: r.w(6),
              runSpacing: r.h(4),
              children: [
                if (c.plate != null)
                  _miniTag(r, 'ทะเบียน ${c.plate}', icon: Icons.directions_car),
                if (c.fleet != null)
                  _miniTag(r, 'Fleet ${c.fleet}', icon: Icons.credit_card),
              ],
            ),
          ],
          for (final extra in c.extras) ...[
            SizedBox(height: r.h(4)),
            Text(
              extra,
              style: TextStyle(fontSize: r.sp(9), color: AppColors.greyMedium),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(Responsive r, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(4)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: r.sp(10), color: AppColors.greyDark),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.corporateBlueDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountLine(
    Responsive r,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.sp(10),
              color: AppColors.greyDark,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: r.sp(bold ? 13 : 11),
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.corporateBlueDark,
          ),
        ),
      ],
    );
  }

  Widget _moneyBox(
    Responsive r, {
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.w(8),
        vertical: r.h(8),
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.greyLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(9),
              color: AppColors.greyMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: r.sp(13),
              fontWeight: FontWeight.w900,
              color: highlight ? AppColors.success : AppColors.corporateBlueDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(Responsive r, String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(4)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: r.sp(10),
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _miniTag(Responsive r, String text, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(3)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.greyLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: r.sp(12), color: AppColors.corporateBlue),
            SizedBox(width: r.w(4)),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: r.sp(9),
              fontWeight: FontWeight.w600,
              color: AppColors.corporateBlueDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(
    Responsive r,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: r.sp(13), color: AppColors.greyMedium),
          SizedBox(width: r.w(6)),
          SizedBox(
            width: r.w(52),
            child: Text(
              label,
              style: TextStyle(
                fontSize: r.sp(10),
                color: AppColors.greyMedium,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: r.sp(10),
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.corporateBlueDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Responsive r, bool wide) {
    final retry = widget.printRequested && !widget.printed;

    if (wide) {
      return Row(
        children: [
          if (retry) ...[
            Expanded(
              child: PrimaryButton(
                label: 'ลองพิมพ์อีกครั้ง',
                icon: Icons.print_rounded,
                variant: ButtonVariant.outline,
                loading: _retrying,
                onPressed: _retryPrint,
              ),
            ),
            SizedBox(width: r.w(8)),
          ],
          Expanded(
            flex: retry ? 2 : 1,
            child: PrimaryButton(
              label: 'เริ่มรายการใหม่',
              icon: Icons.add_rounded,
              onPressed: _newTransaction,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (retry) ...[
          PrimaryButton(
            label: 'ลองพิมพ์อีกครั้ง',
            icon: Icons.print_rounded,
            variant: ButtonVariant.outline,
            loading: _retrying,
            onPressed: _retryPrint,
          ),
          SizedBox(height: r.h(6)),
        ],
        PrimaryButton(
          label: 'เริ่มรายการใหม่',
          icon: Icons.add_rounded,
          onPressed: _newTransaction,
        ),
      ],
    );
  }

  static String _paymentLabel(String code) {
    switch (code) {
      case 'CASH':
        return 'เงินสด';
      case 'TRANSFER':
        return 'โอนเงิน';
      case 'QR':
        return 'QR Code';
      case 'CARD':
        return 'บัตรเครดิต';
      default:
        return code;
    }
  }
}
