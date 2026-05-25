import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/session_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/customer.dart';
import '../../data/models/dispenser.dart';
import '../../data/models/transaction.dart';
import '../../data/models/tank.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/dispenser_repository.dart';
import '../../data/repositories/fuel_repository.dart';
import '../../data/repositories/suspended_sale_repository.dart';
import '../../data/repositories/tank_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../core/constants/license_features.dart';
import '../providers/app_state.dart';
import '../widgets/close_shift_dialog.dart';
import '../widgets/dashboard/market_price_panel.dart';
import '../widgets/dashboard/nozzle_matrix_panel.dart';
import '../widgets/dashboard/numpad_action_panel.dart';
import '../widgets/dashboard/sale_entry_panel.dart';
import '../widgets/dashboard/sidebar_navigation.dart';
import '../widgets/dashboard/tank_inventory_panel.dart';
import '../widgets/fleet_card_dialog.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/customer_picker_dialog.dart';
import '../widgets/high_end_dialog.dart';
import '../widgets/payment_method_picker.dart';
import '../widgets/primary_button.dart';
import '../widgets/suspended_sales_dialog.dart';
import 'backend/backend_home_screen.dart';
import 'dashboard_customers_screen.dart';
import 'dashboard_daily_summary_screen.dart';
import 'dashboard_products_screen.dart';
import 'login_screen.dart';
import 'receive_amount_screen.dart';
import 'summary_screen.dart';

class PosDashboardScreen extends StatefulWidget {
  const PosDashboardScreen({super.key});

  @override
  State<PosDashboardScreen> createState() => _PosDashboardScreenState();
}

class _PosDashboardScreenState extends State<PosDashboardScreen> {
  final _dispenserRepo = DispenserRepository();
  final _tankRepo = TankRepository();
  final _fuelRepo = FuelRepository();
  final _suspendRepo = SuspendedSaleRepository();
  final _txRepo = TransactionRepository();

  List<Dispenser> _dispensers = [];
  List<Map<String, dynamic>> _nozzles = [];
  Map<int, int> _nozzleCounts = {};
  List<Tank> _tanks = [];
  List<Map<String, dynamic>> _fuelPrices = [];
  bool _loading = true;
  String _timeStr = '';
  Timer? _timer;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    SessionService.instance.bind(onTimeout: _handleLogout);
    _loadData();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTime());
    _updateTime();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBackupWarningIfNeeded());
  }

  void _showBackupWarningIfNeeded() {
    if (!mounted) return;
    final warning = context.read<AppState>().backupWarning;
    if (warning == null || warning.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(warning),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'ปิด',
          textColor: AppColors.white,
          onPressed: () => context.read<AppState>().clearBackupWarning(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeStr =
          '${now.day} / ${now.month} / ${now.year + 543}\n${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} น.';
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final dispensers = await _dispenserRepo.listActive();
    final tanks = await _tankRepo.listAll();
    final fuels = await _fuelRepo.listActive();
    final nozzleCounts = await _dispenserRepo.nozzleCountsByDispenser();

    if (!mounted) return;
    setState(() {
      _dispensers = dispensers;
      _tanks = tanks;
      _nozzleCounts = nozzleCounts;
      _fuelPrices = fuels
          .map((f) => {
                'name': f.name,
                'price_per_liter': f.pricePerLiter,
              })
          .toList();
      _loading = false;
    });

    if (_tabIndex != 0) return;

    final state = context.read<AppState>();
    if (dispensers.isEmpty) {
      state.selectDispenser(null);
      setState(() => _nozzles = []);
      return;
    }

    final savedId = state.selectedDispenser?.id;
    Dispenser? pick;
    for (final d in dispensers) {
      if (d.id == savedId) {
        pick = d;
        break;
      }
    }
    pick ??= dispensers.first;
    await _selectDispenser(pick, keepNozzleIfPossible: true);
  }

  Future<void> _selectDispenser(
    Dispenser d, {
    bool keepNozzleIfPossible = false,
    bool autoSelectFirstNozzle = true,
  }) async {
    if (d.id == null) return;
    final state = context.read<AppState>();
    state.selectDispenser(d);
    final nozzles = await _dispenserRepo.getDetailedNozzles(d.id!);
    if (!mounted) return;

    setState(() => _nozzles = nozzles);

    if (nozzles.isEmpty) return;

    if (keepNozzleIfPossible) {
      final prevId = state.selectedNozzle?['id'];
      for (final n in nozzles) {
        if (n['id'] == prevId) {
          state.selectNozzle(n);
          return;
        }
      }
    }
    if (autoSelectFirstNozzle) {
      state.selectNozzle(nozzles.first);
    }
  }

  void _selectNozzle(Map<String, dynamic> n) {
    context.read<AppState>().selectNozzle(n);
  }

  Future<void> _openBackend() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BackendHomeScreen()),
    );
    if (!mounted) return;
    setState(() => _tabIndex = 0);
    await _loadData();
  }

  Future<void> _handlePay() async {
    final state = context.read<AppState>();
    if (state.liters <= 0) {
      ToastUtils.show(context, 'กรุณาระบุจำนวนเงินหรือลิตร');
      return;
    }
    if (state.fuel == null) {
      ToastUtils.show(context, 'กรุณาเลือกน้ำมัน');
      return;
    }

    final method = await HighEndDialog.show<PaymentMethod>(
      context: context,
      title: 'เลือกช่องทางชำระเงิน',
      icon: Icons.payments_rounded,
      compact: true,
      maxWidth: 420,
      content: PaymentMethodPicker(
        onSelected: (m) => Navigator.pop(context, m),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก',
              style: TextStyle(
                  color: AppColors.greyMedium, fontWeight: FontWeight.bold)),
        )
      ],
    );

    if (method == null || !mounted) return;
    state.setPaymentMethod(method);

    if (method.requiresChange) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReceiveAmountScreen()),
      );
    } else {
      state.setReceivedAmount(state.total);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SummaryScreen()),
      );
    }
    if (!mounted) return;
    await _loadData();
    if (!mounted) return;
    context.read<AppState>().resetTransaction();
  }

  Future<void> _handlePrint() async {
    final state = context.read<AppState>();
    final user = state.user;
    if (user == null) return;

    final cashierName = user.displayName ?? user.username;
    final printer = BluetoothPrinterService.instance;

    if (state.fuel != null && state.liters > 0) {
      final draft = Transaction.draft(
        cashierId: user.id,
        fuelTypeId: state.fuel!.id,
        paymentMethod: state.paymentMethod?.code ?? 'PENDING',
        liters: state.liters,
        pricePerLiter: state.fuel!.pricePerLiter,
        subtotal: state.subtotal,
        total: state.total,
        notes: state.selectedCustomer?.formatTaxNotes(),
      );
      final ok = await printer.printReceipt(
        tx: draft,
        fuelName: state.fuel!.name,
        cashierName: cashierName,
        customer: state.selectedCustomer,
        isDraft: true,
      );
      if (!mounted) return;
      ToastUtils.show(
        context,
        ok ? 'พิมพ์ใบแจ้งหนี้แล้ว' : 'เชื่อมต่อเครื่องพิมพ์ไม่ได้ — ตั้งค่าใน Backend',
      );
      return;
    }

    final last = await _txRepo.getLastForCashier(user.id);
    if (!mounted) return;
    if (last == null) {
      ToastUtils.show(context, 'ไม่มีรายการล่าสุดให้พิมพ์');
      return;
    }
    final fuel = await FuelRepository().getById(last.fuelTypeId);
    Customer? customer;
    if (last.customerId != null) {
      customer = await CustomerRepository().getById(last.customerId!);
    }
    final ok = await printer.printReceipt(
      tx: last,
      fuelName: fuel?.name ?? 'Fuel',
      cashierName: cashierName,
      customer: customer,
    );
    if (!mounted) return;
    if (ok) await _txRepo.markPrinted(last.id);
    if (!mounted) return;
    ToastUtils.show(
      context,
      ok ? 'พิมพ์ใบเสร็จซ้ำแล้ว' : 'เชื่อมต่อเครื่องพิมพ์ไม่ได้',
    );
  }

  Future<void> _handleSuspend() async {
    final state = context.read<AppState>();
    if (state.fuel == null || state.liters <= 0) {
      ToastUtils.show(context, 'ไม่มีรายการให้พัก');
      return;
    }
    await _suspendRepo.save(
      cashierId: state.user!.id,
      payload: state.toSuspendPayload(),
    );
    if (!mounted) return;
    state.resetTransaction();
    ToastUtils.show(context, 'พักรายการขายแล้ว');
  }

  void _handleLogout() {
    SessionService.instance.dispose();
    context.read<AppState>().logout();
    unawaited(AuthSessionService.instance.clearSession());
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _handleCloseShift() async {
    final state = context.read<AppState>();
    final user = state.user;
    final shift = state.shift;

    if (user == null || shift == null) {
      ToastUtils.show(context, 'ไม่พบกะที่เปิดอยู่');
      return;
    }

    if (state.fuel != null && (state.liters > 0 || state.fuelAmount > 0)) {
      final discard = await HighEndDialog.show<bool>(
        context: context,
        title: 'มีรายการค้างอยู่',
        message: 'มีรายการขายที่ยังไม่เสร็จ ต้องการล้างและปิดกะหรือไม่?',
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.gold,
        maxWidth: 400,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          PrimaryButton(
            label: 'ล้างและปิดกะ',
            variant: ButtonVariant.outline,
            expand: false,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );
      if (discard != true || !mounted) return;
      state.resetTransaction();
    }

    final outcome = await CloseShiftDialog.show(
      context,
      shiftId: shift.id,
      userId: user.id,
    );
    if (!mounted || outcome == CloseShiftOutcome.cancelled) return;

    state.setShift(null);
    await AuthSessionService.instance.clearShiftId();

    if (outcome == CloseShiftOutcome.openedNewShift) {
      final newShift = await OpenShiftDialog.show(context, userId: user.id);
      if (!mounted) return;
      if (newShift == null) {
        _handleLogout();
        return;
      }
      state.setShift(newShift);
      await AuthSessionService.instance.saveSession(
        username: user.username,
        userId: user.id,
        shiftId: newShift.id,
      );
      ToastUtils.show(context, 'เปิดกะ #${newShift.id} แล้ว');
      return;
    }

    _handleLogout();
  }

  void _onTabSelect(int idx) {
    final state = context.read<AppState>();
    if (idx == 1 && !state.canUse(AppFeature.productSales)) {
      ToastUtils.show(context, 'Package นี้ไม่รองรับขายสินค้าทั่วไป');
      return;
    }
    if (idx == 4) {
      if (state.user?.isAdmin == true) {
        _openBackend();
      } else {
        ToastUtils.show(context, 'เฉพาะผู้ดูแลระบบ');
      }
      return;
    }
    setState(() => _tabIndex = idx);
    if (idx == 0) _loadData();
  }

  Widget _buildFuelTab(Responsive r, AppState state) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    return Padding(
      padding: EdgeInsets.all(r.w(10)),
      child: Row(
        children: [
          Expanded(
            flex: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: NozzleMatrixPanel(
                    dispensers: _dispensers,
                    selectedDispenser: state.selectedDispenser,
                    nozzles: _nozzles,
                    nozzleCounts: _nozzleCounts,
                    onSelectDispenser: (d) => _selectDispenser(
                          d,
                          autoSelectFirstNozzle: false,
                        ),
                    onSelectNozzle: _selectNozzle,
                  ),
                ),
                SizedBox(height: r.h(8)),
                TankInventoryPanel(tanks: _tanks),
              ],
            ),
          ),
          SizedBox(width: r.w(8)),
          Expanded(
            flex: 28,
            child: SaleEntryPanel(
              onPay: _handlePay,
              onSuspend: _handleSuspend,
              onCancel: () => state.resetTransaction(),
              onPrint: _handlePrint,
              onSelectCustomer: () => CustomerPickerDialog.show(context),
            ),
          ),
          SizedBox(width: r.w(8)),
          Expanded(
            flex: 18,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: MarketPricePanel(fuelPrices: _fuelPrices),
                ),
                SizedBox(height: r.h(8)),
                Expanded(
                  flex: 2,
                  child: NumpadActionPanel(
                    onPay: _handlePay,
                    onCancel: () => state.resetTransaction(),
                    onSuspend: _handleSuspend,
                    onFleetCard: () => FleetCardDialog.show(context),
                    onSuspendedList: () async {
                      final restored =
                          await SuspendedSalesDialog.show(context);
                      if (restored && mounted) {
                        final d = context.read<AppState>().selectedDispenser;
                        if (d != null) {
                          await _selectDispenser(d, keepNozzleIfPossible: true);
                        }
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final state = context.watch<AppState>();
    final productsEnabled = state.canUse(AppFeature.productSales);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SidebarNavigation(
            selectedIndex: _tabIndex,
            productsEnabled: productsEnabled,
            onSelect: _onTabSelect,
            onLogout: _handleLogout,
            onSuspendedList: () async {
              final restored = await SuspendedSalesDialog.show(context);
              if (restored && mounted) {
                setState(() => _tabIndex = 0);
                await _loadData();
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: AppColors.corporateBlueDark,
                  padding: EdgeInsets.symmetric(
                      horizontal: r.w(24), vertical: r.h(8)),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _handleCloseShift,
                        icon: Icon(Icons.lock_clock_rounded, size: r.sp(16)),
                        label: Text(
                          state.shift != null
                              ? 'ปิดกะ #${state.shift!.id}'
                              : 'ปิดกะ',
                          style: TextStyle(
                            fontSize: r.sp(12),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.white,
                          side: BorderSide(
                            color: AppColors.white.withValues(alpha: 0.55),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: r.w(12),
                            vertical: r.h(6),
                          ),
                        ),
                      ),
                      SizedBox(width: r.w(12)),
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: r.sp(20),
                            fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Text(_timeStr.replaceAll('\n', ' '),
                          style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.8),
                              fontSize: r.sp(10))),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildFuelTab(r, state),
                      const DashboardProductsScreen(),
                      const DashboardDailySummaryScreen(),
                      const DashboardCustomersScreen(),
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
