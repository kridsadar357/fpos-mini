import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/product_stock_movement.dart';
import '../../../data/repositories/product_stock_repository.dart';
import '../../../core/constants/license_features.dart';
import '../../widgets/license_gate.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pos_header.dart';

class ProductStockReportScreen extends StatefulWidget {
  const ProductStockReportScreen({super.key});

  @override
  State<ProductStockReportScreen> createState() =>
      _ProductStockReportScreenState();
}

class _ProductStockReportScreenState extends State<ProductStockReportScreen> {
  final _repo = ProductStockRepository();
  List<ProductStockSummary> _summary = [];
  List<ProductStockMovement> _movements = [];
  int _days = 7;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final to = DateTime.now();
    final from = DateTime(to.year, to.month, to.day)
        .subtract(Duration(days: _days - 1));
    final summary = await _repo.summaryForPeriod(from: from, to: to);
    final movements = await _repo.listMovements(from: from, to: to, limit: 150);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _movements = movements;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LicenseGate(
      feature: AppFeature.productStock,
      title: 'คลังสินค้า',
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        compact: true,
        title: 'คลังสินค้า',
        subtitle: 'สต็อก + ประวัติ $_days วันล่าสุด',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(r.w(12)),
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('วันนี้')),
                      ButtonSegment(value: 7, label: Text('7 วัน')),
                      ButtonSegment(value: 30, label: Text('30 วัน')),
                    ],
                    selected: {_days},
                    onSelectionChanged: (s) {
                      setState(() => _days = s.first);
                      _load();
                    },
                  ),
                  SizedBox(height: r.h(10)),
                  Text(
                    'สต็อกปัจจุบัน',
                    style: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w800,
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                  SizedBox(height: r.h(6)),
                  ..._summary.map((s) => _StockCard(summary: s, r: r)),
                  SizedBox(height: r.h(12)),
                  Text(
                    'ประวัติเคลื่อนไหว',
                    style: TextStyle(
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w800,
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                  SizedBox(height: r.h(6)),
                  if (_movements.isEmpty)
                    GlassCard(
                      padding: EdgeInsets.all(r.w(16)),
                      child: Text(
                        'ไม่มีประวัติในช่วงเวลานี้',
                        style: TextStyle(
                          color: AppColors.greyMedium,
                          fontSize: r.sp(11),
                        ),
                      ),
                    )
                  else
                    ..._movements.map((m) => _MovementTile(movement: m, r: r)),
                ],
              ),
            ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final ProductStockSummary summary;
  final Responsive r;

  const _StockCard({required this.summary, required this.r});

  @override
  Widget build(BuildContext context) {
    final low = summary.currentQty <= 5;
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(6)),
      child: GlassCard(
        padding: EdgeInsets.all(r.w(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.productName,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: r.sp(12),
                      color: AppColors.corporateBlueDark,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.w(8),
                    vertical: r.h(2),
                  ),
                  decoration: BoxDecoration(
                    color: (low ? AppColors.danger : AppColors.corporateBlue)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${summary.currentQty} ชิ้น',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: r.sp(11),
                      color: low ? AppColors.danger : AppColors.corporateBlue,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.h(6)),
            Wrap(
              spacing: r.w(8),
              runSpacing: r.h(4),
              children: [
                _chip('รับเข้า', summary.received, AppColors.success),
                _chip('ขาย', summary.sold, AppColors.corporateBlue),
                _chip('แถมโปร', summary.promoGiven, AppColors.fuel95),
                if (summary.adjusted != 0)
                  _chip('ปรับยอด', summary.adjusted.abs(), AppColors.greyDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int value, Color color) {
    return Text(
      '$label $value',
      style: TextStyle(
        fontSize: r.sp(9),
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final ProductStockMovement movement;
  final Responsive r;

  const _MovementTile({required this.movement, required this.r});

  @override
  Widget build(BuildContext context) {
    final delta = movement.qtyDelta;
    final color = delta > 0 ? AppColors.success : AppColors.danger;
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(4)),
      child: GlassCard(
        padding: EdgeInsets.symmetric(
          horizontal: r.w(10),
          vertical: r.h(8),
        ),
        child: Row(
          children: [
            Container(
              width: r.w(36),
              alignment: Alignment.center,
              child: Text(
                delta > 0 ? '+$delta' : '$delta',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: r.sp(12),
                  color: color,
                ),
              ),
            ),
            SizedBox(width: r.w(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.productName ?? 'สินค้า',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: r.sp(10),
                    ),
                  ),
                  Text(
                    '${movement.typeLabel} • คงเหลือ ${movement.qtyAfter} • ${Fmt.receiptDate(movement.createdAt)}',
                    style: TextStyle(
                      fontSize: r.sp(9),
                      color: AppColors.greyMedium,
                    ),
                  ),
                  if (movement.note != null && movement.note!.isNotEmpty)
                    Text(
                      movement.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.sp(8),
                        color: AppColors.greyDark,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
