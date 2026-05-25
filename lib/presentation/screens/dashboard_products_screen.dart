import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/product.dart';
import '../../data/models/product_cart_line.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/high_end_dialog.dart';
import '../widgets/payment_method_picker.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_cart_panel.dart';
import '../widgets/product_thumbnail.dart';
import 'product_receive_amount_screen.dart';

class DashboardProductsScreen extends StatefulWidget {
  const DashboardProductsScreen({super.key});

  @override
  State<DashboardProductsScreen> createState() =>
      _DashboardProductsScreenState();
}

class _DashboardProductsScreenState extends State<DashboardProductsScreen> {
  final _repo = ProductRepository();
  final _txRepo = TransactionRepository();
  List<Product> _products = [];
  final List<ProductCartLine> _cart = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.listActive();
    setState(() {
      _products = list;
      _loading = false;
    });
  }

  double get _cartTotal =>
      _cart.fold(0.0, (sum, line) => sum + line.lineTotal);

  int get _cartQty => _cart.fold(0, (sum, line) => sum + line.quantity);

  void _addProduct(Product p) {
    if (p.currentQty <= 0) {
      ToastUtils.show(context, '${p.name} หมดสต็อก');
      return;
    }
    setState(() {
      final idx = _cart.indexWhere((l) => l.product.id == p.id);
      if (idx >= 0) {
        if (_cart[idx].quantity >= p.currentQty) {
          ToastUtils.show(context, 'สต็อก${p.name}มี ${p.currentQty} ชิ้น');
          return;
        }
        _cart[idx].quantity++;
      } else {
        _cart.add(ProductCartLine(product: p));
      }
    });
  }

  void _changeQty(ProductCartLine line, int delta) {
    setState(() {
      final idx = _cart.indexOf(line);
      if (idx < 0) return;
      final next = line.quantity + delta;
      if (next <= 0) {
        _cart.removeAt(idx);
      } else if (next > line.product.currentQty) {
        ToastUtils.show(
          context,
          'สต็อก${line.product.name}มี ${line.product.currentQty} ชิ้น',
        );
      } else {
        _cart[idx].quantity = next;
      }
    });
  }

  void _removeLine(ProductCartLine line) {
    setState(() => _cart.remove(line));
  }

  void _clearCart() => setState(() => _cart.clear());

  Future<void> _checkout() async {
    final state = context.read<AppState>();
    if (state.user == null || _cart.isEmpty) return;

    final total = _cartTotal;
    final itemLabel =
        '${_cart.length} รายการ • $_cartQty ชิ้น • ${Fmt.money(total)}';

    final method = await HighEndDialog.show<PaymentMethod>(
      context: context,
      title: 'เลือกช่องทางชำระเงิน',
      icon: Icons.payments_rounded,
      message: itemLabel,
      compact: true,
      maxWidth: 420,
      content: PaymentMethodPicker(
        onSelected: (m) => Navigator.pop(context, m),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'ยกเลิก',
            style: TextStyle(
              color: AppColors.greyMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
    if (method == null || !mounted) return;

    double received = total;
    double change = 0;

    if (method.requiresChange) {
      final amount = await Navigator.of(context).push<double>(
        MaterialPageRoute(
          builder: (_) => ProductReceiveAmountScreen(
            total: total,
            subtitle: itemLabel,
            itemCount: _cartQty,
          ),
        ),
      );
      if (amount == null || !mounted) return;
      received = amount;
      change = (received - total).clamp(0, double.infinity);
    }

    final shouldPrint = await HighEndDialog.show<bool>(
      context: context,
      title: 'พิมพ์ใบเสร็จ',
      icon: Icons.print_rounded,
      maxWidth: 360,
      message: 'ต้องการพิมพ์ใบเสร็จสำหรับรายการสินค้านี้หรือไม่?',
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
    if (shouldPrint == null || !mounted) return;

    try {
      await _txRepo.createProductCartSale(
        cashierId: state.user!.id,
        shiftId: state.shift?.id,
        lines: _cart
            .map(
              (l) => (
                productId: l.product.id!,
                name: l.product.name,
                price: l.product.price,
                qty: l.quantity,
              ),
            )
            .toList(),
        paymentMethod: method.code,
        total: total,
        received: received,
        changeAmount: change,
      );
    } on StockInsufficientException catch (e) {
      if (mounted) ToastUtils.show(context, e.toString());
      return;
    }

    if (!mounted) return;
    _clearCart();
    await _load();
    if (!mounted) return;
    ToastUtils.show(
      context,
      shouldPrint
          ? 'บันทึกการขายสินค้าแล้ว (รอเชื่อมต่อเครื่องพิมพ์)'
          : 'บันทึกการขายสินค้าแล้ว',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Padding(
      padding: EdgeInsets.all(r.w(10)),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: GlassCard(
                    padding: EdgeInsets.all(r.w(10)),
                    child: _products.isEmpty
                        ? const Center(child: Text('ไม่มีสินค้า'))
                        : GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: r.isTablet ? 3 : 2,
                              crossAxisSpacing: r.w(8),
                              mainAxisSpacing: r.h(8),
                              childAspectRatio: 1.15,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (_, i) {
                              final p = _products[i];
                              final inCart = _cart.any(
                                (l) => l.product.id == p.id,
                              );
                              final qty = inCart
                                  ? _cart
                                      .firstWhere(
                                          (l) => l.product.id == p.id)
                                      .quantity
                                  : 0;
                              return _ProductTile(
                                product: p,
                                cartQty: qty,
                                onTap: () => _addProduct(p),
                              );
                            },
                          ),
                  ),
                ),
                SizedBox(width: r.w(8)),
                Expanded(
                  flex: 2,
                  child: GlassCard(
                    padding: EdgeInsets.all(r.w(10)),
                    child: ProductCartPanel(
                      lines: _cart,
                      total: _cartTotal,
                      totalQty: _cartQty,
                      onClear: _clearCart,
                      onCheckout: _checkout,
                      onChangeQty: _changeQty,
                      onRemove: _removeLine,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final int cartQty;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.cartQty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final inCart = cartQty > 0;
    final outOfStock = product.currentQty <= 0;

    return Material(
      color: outOfStock
          ? AppColors.greyLight.withValues(alpha: 0.35)
          : inCart
              ? AppColors.corporateBlue.withValues(alpha: 0.08)
              : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: inCart
                  ? AppColors.corporateBlue
                  : AppColors.greyLight,
              width: inCart ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(r.w(8)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ProductThumbnail(
                      imagePath: product.imagePath,
                      size: r.w(48),
                    ),
                    SizedBox(height: r.h(4)),
                    Text(
                      product.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: r.sp(11),
                      ),
                    ),
                    Text(
                      Fmt.money(product.price),
                      style: TextStyle(
                        color: AppColors.corporateBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: r.sp(12),
                      ),
                    ),
                    Text(
                      outOfStock
                          ? 'หมดสต็อก'
                          : 'คงเหลือ ${product.currentQty}',
                      style: TextStyle(
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w700,
                        color: outOfStock || product.isLowStock
                            ? AppColors.danger
                            : AppColors.greyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              if (inCart)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.corporateBlue,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 22, minHeight: 22),
                    alignment: Alignment.center,
                    child: Text(
                      '$cartQty',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
