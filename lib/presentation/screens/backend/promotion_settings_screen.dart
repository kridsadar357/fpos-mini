import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/fuel_type.dart';
import '../../../data/models/product.dart';
import '../../../data/models/promotion.dart';
import '../../../data/repositories/fuel_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/promotion_repository.dart';
import '../../../core/constants/license_features.dart';
import '../../widgets/license_gate.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';

class PromotionSettingsScreen extends StatefulWidget {
  const PromotionSettingsScreen({super.key});

  @override
  State<PromotionSettingsScreen> createState() =>
      _PromotionSettingsScreenState();
}

class _PromotionSettingsScreenState extends State<PromotionSettingsScreen> {
  final _repo = PromotionRepository();
  final _fuelRepo = FuelRepository();
  final _productRepo = ProductRepository();

  List<Promotion> _promos = [];
  List<FuelType> _fuels = [];
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final promos = await _repo.listAll();
    final fuels = await _fuelRepo.listAll();
    final products = await _productRepo.listActive();
    setState(() {
      _promos = promos;
      _fuels = fuels;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _toggle(Promotion p, bool active) async {
    await _repo.setActive(p.id, active);
    await _load();
  }

  Future<void> _delete(Promotion p) async {
    final ok = await HighEndDialog.show<bool>(
      context: context,
      title: 'ลบโปรโมชั่น',
      message: p.name,
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.redBright,
      actions: [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => Navigator.pop(context, false),
        ),
        PrimaryButton(
          label: 'ลบ',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (ok == true) {
      await _repo.delete(p.id);
      await _load();
    }
  }

  String _valueLabel(Promotion p) {
    if (p.isFreeProduct) {
      if (p.minAmount > 0) {
        return 'ทุก ${Fmt.money(p.minAmount)} แถม ${p.rewardQty} ชิ้น';
      }
      return p.freeProductLabel();
    }
    if (p.type == 'percent') return '${p.value.toStringAsFixed(1)}%';
    if (p.type == 'per_liter') return '${Fmt.money(p.value)} / ลิตร';
    return Fmt.money(p.value);
  }

  Future<void> _edit(Promotion p) async {
    var products = _products;
    if (p.rewardProductId != null &&
        !products.any((x) => x.id == p.rewardProductId)) {
      final extra = await _productRepo.getById(p.rewardProductId!);
      if (extra != null) products = [...products, extra];
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<_NewPromoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => _NewPromoSheet(
        fuels: _fuels,
        products: products,
        existing: p,
      ),
    );
    if (result == null) return;
    await _repo.update(Promotion(
      id: p.id,
      name: result.name,
      description: result.description,
      type: result.type,
      value: result.value,
      minAmount: result.minAmount,
      fuelTypeId: result.fuelTypeId,
      rewardProductId: result.rewardProductId,
      rewardQty: result.rewardQty,
      isActive: p.isActive,
      createdAt: p.createdAt,
    ));
    await _load();
  }

  Future<void> _create() async {
    final result = await showModalBottomSheet<_NewPromoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => _NewPromoSheet(fuels: _fuels, products: _products),
    );
    if (result == null) return;
    await _repo.insert(Promotion(
      id: 0,
      name: result.name,
      description: result.description,
      type: result.type,
      value: result.value,
      minAmount: result.minAmount,
      fuelTypeId: result.fuelTypeId,
      rewardProductId: result.rewardProductId,
      rewardQty: result.rewardQty,
      isActive: true,
      createdAt: DateTime.now(),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return LicenseGate(
      feature: AppFeature.promotions,
      title: 'โปรโมชั่น',
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'โปรโมชั่น',
        subtitle: 'ส่วนลดและเงื่อนไข',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.white),
            onPressed: _create,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: EdgeInsets.all(r.w(16)),
              itemCount: _promos.length,
              separatorBuilder: (_, __) => SizedBox(height: r.h(8)),
              itemBuilder: (_, i) {
                final p = _promos[i];
                final fuelName = p.fuelTypeId == null
                    ? 'น้ำมันทุกชนิด'
                    : _fuels
                        .firstWhere(
                          (f) => f.id == p.fuelTypeId,
                          orElse: () => FuelType(
                            id: 0,
                            code: '',
                            name: 'ไม่ระบุ',
                            pricePerLiter: 0,
                          ),
                        )
                        .name;
                return GlassCard(
                  padding: EdgeInsets.all(r.w(8)),
                  child: ListTile(
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: p.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      '${_valueLabel(p)} • $fuelName • ขั้นต่ำ ${Fmt.money(p.minAmount)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: p.isActive,
                          onChanged: (v) => _toggle(p, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.corporateBlue),
                          onPressed: () => _edit(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.redBright),
                          onPressed: () => _delete(p),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NewPromoResult {
  final String name;
  final String description;
  final String type;
  final double value;
  final double minAmount;
  final int? fuelTypeId;
  final int? rewardProductId;
  final int rewardQty;

  _NewPromoResult({
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.minAmount,
    this.fuelTypeId,
    this.rewardProductId,
    this.rewardQty = 1,
  });
}

class _NewPromoSheet extends StatefulWidget {
  final List<FuelType> fuels;
  final List<Product> products;
  final Promotion? existing;

  const _NewPromoSheet({
    required this.fuels,
    required this.products,
    this.existing,
  });

  @override
  State<_NewPromoSheet> createState() => _NewPromoSheetState();
}

class _NewPromoSheetState extends State<_NewPromoSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _value = TextEditingController(text: '5');
  final _min = TextEditingController(text: '0');
  final _rewardQty = TextEditingController(text: '1');
  late String _type;
  int? _fuelId;
  int? _productId;

  bool get _isEditing => widget.existing != null;
  bool get _isFreeProduct => _type == 'free_product';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _desc.text = e.description ?? '';
      _type = e.type;
      _value.text = e.isFreeProduct ? '0' : e.value.toString();
      _min.text = e.minAmount.toString();
      _fuelId = e.fuelTypeId;
      _productId = e.rewardProductId;
      _rewardQty.text = e.rewardQty.toString();
    } else {
      _type = 'percent';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _value.dispose();
    _min.dispose();
    _rewardQty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEditing ? 'แก้ไขโปรโมชั่น' : 'โปรโมชั่นใหม่',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.corporateBlueDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ชื่อ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'รายละเอียด'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'ประเภท'),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('ลด %')),
                  DropdownMenuItem(
                      value: 'fixed', child: Text('ลดจำนวนเงิน')),
                  DropdownMenuItem(
                      value: 'per_liter', child: Text('ลดต่อลิตร')),
                  DropdownMenuItem(
                      value: 'free_product', child: Text('แถมสินค้า')),
                ],
                onChanged: (v) => setState(() {
                  _type = v ?? 'percent';
                  if (_isFreeProduct) _value.text = '0';
                }),
              ),
              const SizedBox(height: 10),
              if (_isFreeProduct) ...[
                DropdownButtonFormField<int>(
                  initialValue: _productId,
                  decoration: const InputDecoration(labelText: 'สินค้าแถม'),
                  items: widget.products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} (${Fmt.money(p.price)}) • คงเหลือ ${p.currentQty}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _productId = v),
                ),
                if (widget.products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'ยังไม่มีสินค้า — เพิ่มในเมนูสินค้าทั่วไปก่อน',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _rewardQty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนแถมต่อ 1 สิทธิ (ชิ้น)',
                    helperText: 'เช่น เติม 500 แถม 1 → ตั้งจำนวนแถม = 1',
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _min,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ยอดเติมต่อ 1 สิทธิ (บาท)',
                    helperText: 'เช่น 500 = ทุก 500 บาทได้สิทธิ 1 ครั้ง (2000 = 4 ครั้ง)',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'มูลค่า'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _min,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'ยอดขั้นต่ำ (บาท)'),
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: _fuelId,
                decoration:
                    const InputDecoration(labelText: 'ใช้กับน้ำมัน'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('ทุกชนิด')),
                  ...widget.fuels.map(
                    (f) => DropdownMenuItem(value: f.id, child: Text(f.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _fuelId = v),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _isEditing ? 'บันทึก' : 'สร้าง',
                onPressed: () {
                  final minAmount = double.tryParse(_min.text) ?? 0;
                  if (_name.text.trim().isEmpty) return;

                  if (_isFreeProduct) {
                    if (_productId == null) return;
                    final qty = int.tryParse(_rewardQty.text) ?? 0;
                    if (qty <= 0) return;
                    Navigator.pop(
                      context,
                      _NewPromoResult(
                        name: _name.text.trim(),
                        description: _desc.text.trim(),
                        type: _type,
                        value: 0,
                        minAmount: minAmount,
                        fuelTypeId: _fuelId,
                        rewardProductId: _productId,
                        rewardQty: qty,
                      ),
                    );
                    return;
                  }

                  final value = double.tryParse(_value.text) ?? 0;
                  if (value <= 0) return;
                  Navigator.pop(
                    context,
                    _NewPromoResult(
                      name: _name.text.trim(),
                      description: _desc.text.trim(),
                      type: _type,
                      value: value,
                      minAmount: minAmount,
                      fuelTypeId: _fuelId,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
