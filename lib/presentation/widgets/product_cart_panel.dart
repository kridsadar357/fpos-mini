import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatter.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/product_cart_line.dart';
import 'primary_button.dart';

class ProductCartPanel extends StatelessWidget {
  final List<ProductCartLine> lines;
  final double total;
  final int totalQty;
  final VoidCallback onClear;
  final VoidCallback onCheckout;
  final void Function(ProductCartLine line, int delta) onChangeQty;
  final void Function(ProductCartLine line) onRemove;

  const ProductCartPanel({
    super.key,
    required this.lines,
    required this.total,
    required this.totalQty,
    required this.onClear,
    required this.onCheckout,
    required this.onChangeQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart_rounded,
                color: AppColors.corporateBlue, size: r.sp(20)),
            SizedBox(width: r.w(6)),
            Text(
              'ตะกร้า',
              style: TextStyle(
                fontSize: r.sp(16),
                fontWeight: FontWeight.w900,
                color: AppColors.corporateBlueDark,
              ),
            ),
            if (totalQty > 0) ...[
              SizedBox(width: r.w(6)),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(2)),
                decoration: BoxDecoration(
                  color: AppColors.corporateBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalQty',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: r.sp(11),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (lines.isNotEmpty)
              TextButton(
                onPressed: onClear,
                child: Text(
                  'ล้าง',
                  style: TextStyle(
                    fontSize: r.sp(11),
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: lines.isEmpty
              ? Center(
                  child: Text(
                    'แตะสินค้าเพื่อเพิ่มลงตะกร้า',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.greyMedium,
                      fontSize: r.sp(12),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final line = lines[i];
                    return _CartLineTile(
                      line: line,
                      onChangeQty: (d) => onChangeQty(line, d),
                      onRemove: () => onRemove(line),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'รวม',
              style: TextStyle(
                fontSize: r.sp(14),
                fontWeight: FontWeight.w800,
                color: AppColors.greyDark,
              ),
            ),
            Text(
              Fmt.money(total),
              style: TextStyle(
                fontSize: r.sp(20),
                fontWeight: FontWeight.w900,
                color: AppColors.corporateBlue,
              ),
            ),
          ],
        ),
        SizedBox(height: r.h(8)),
        PrimaryButton(
          label: 'ชำระเงิน',
          icon: Icons.payments_rounded,
          onPressed: lines.isEmpty ? null : onCheckout,
        ),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final ProductCartLine line;
  final void Function(int delta) onChangeQty;
  final VoidCallback onRemove;

  const _CartLineTile({
    required this.line,
    required this.onChangeQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final p = line.product;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.h(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: r.sp(12),
                    color: AppColors.corporateBlueDark,
                  ),
                ),
                Text(
                  '${Fmt.money(p.price)} × ${line.quantity}',
                  style: TextStyle(
                    fontSize: r.sp(10),
                    color: AppColors.greyMedium,
                  ),
                ),
                Text(
                  Fmt.money(line.lineTotal),
                  style: TextStyle(
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.w900,
                    color: AppColors.corporateBlue,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyBtn(
                    icon: Icons.remove_rounded,
                    onTap: () => onChangeQty(-1),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.w(6)),
                    child: Text(
                      '${line.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: r.sp(14),
                      ),
                    ),
                  ),
                  _QtyBtn(
                    icon: Icons.add_rounded,
                    onTap: () => onChangeQty(1),
                  ),
                ],
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.corporateBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: AppColors.corporateBlue),
        ),
      ),
    );
  }
}
