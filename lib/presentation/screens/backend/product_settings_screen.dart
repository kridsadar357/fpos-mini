import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatter.dart';
import '../../../core/utils/product_image_util.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/product_stock_repository.dart';
import '../../../core/constants/license_features.dart';
import '../../widgets/license_gate.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/high_end_dialog.dart';
import '../../widgets/pos_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/product_thumbnail.dart';

class ProductSettingsScreen extends StatefulWidget {
  const ProductSettingsScreen({super.key});

  @override
  State<ProductSettingsScreen> createState() => _ProductSettingsScreenState();
}

class _ProductEditorResult {
  final String name;
  final double price;
  final String? sku;
  final String? imagePath;
  final bool removeImage;
  final int stockQty;

  const _ProductEditorResult({
    required this.name,
    required this.price,
    this.sku,
    this.imagePath,
    this.removeImage = false,
    this.stockQty = 0,
  });
}

class _ProductSettingsScreenState extends State<ProductSettingsScreen> {
  final _repo = ProductRepository();
  final _stockRepo = ProductStockRepository();
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.listAll();
    setState(() {
      _products = list;
      _loading = false;
    });
  }

  Future<void> _showEditor({Product? product}) async {
    final formKey = GlobalKey<_ProductEditorContentState>();

    final result = await HighEndDialog.show<_ProductEditorResult>(
      context: context,
      title: product == null ? 'เพิ่มสินค้า' : 'แก้ไขสินค้า',
      icon: Icons.shopping_bag_rounded,
      maxWidth: Responsive.of(context).w(420),
      content: _ProductEditorContent(
        key: formKey,
        product: product,
      ),
      actionBuilders: (dialogContext) => [
        PrimaryButton(
          label: 'ยกเลิก',
          variant: ButtonVariant.outline,
          onPressed: () => HighEndDialog.close(dialogContext),
        ),
        PrimaryButton(
          label: 'บันทึก',
          onPressed: () {
            final data = formKey.currentState?.buildResult();
            if (data == null) return;
            HighEndDialog.close(dialogContext, data);
          },
        ),
      ],
    );

    if (result == null) return;

    if (product == null) {
      final id = await _repo.create(
        name: result.name,
        price: result.price,
        sku: result.sku,
        initialQty: result.stockQty,
      );
      final imagePath = await _resolveImagePath(
        productId: id,
        imagePath: result.imagePath,
        removeImage: result.removeImage,
        previousPath: null,
      );
      if (imagePath != null) {
        await _repo.updateImagePath(id, imagePath);
      }
    } else {
      final imagePath = await _resolveImagePath(
        productId: product.id!,
        imagePath: result.imagePath,
        removeImage: result.removeImage,
        previousPath: product.imagePath,
      );
      await _repo.update(
        id: product.id!,
        name: result.name,
        price: result.price,
        sku: result.sku,
        imagePath: imagePath,
        clearImage: result.removeImage,
      );
      if (result.stockQty > 0) {
        await _stockRepo.receive(
          productId: product.id!,
          qty: result.stockQty,
          note: 'รับเข้าจากแก้ไขสินค้า',
        );
      }
    }

    await _load();
    if (mounted) ToastUtils.show(context, 'บันทึกแล้ว');
  }

  Future<String?> _resolveImagePath({
    required int productId,
    required String? imagePath,
    required bool removeImage,
    required String? previousPath,
  }) async {
    if (removeImage) {
      await ProductImageUtil.deleteIfExists(previousPath);
      return null;
    }
    if (imagePath == null || imagePath == previousPath) return previousPath;
    if (imagePath.contains('product_tmp_')) {
      await ProductImageUtil.deleteIfExists(previousPath);
      return ProductImageUtil.finalizeTempPath(imagePath, productId);
    }
    return imagePath;
  }

  @override
  Widget build(BuildContext context) {
    return LicenseGate(
      feature: AppFeature.productManagement,
      title: 'จัดการสินค้า',
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PosHeader(
        title: 'จัดการสินค้า',
        subtitle: 'สินค้าหน้าร้าน (น้ำดื่ม ฯลฯ)',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.white),
            onPressed: () => _showEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: EdgeInsets.all(r.w(16)),
              itemCount: _products.length,
              separatorBuilder: (_, __) => SizedBox(height: r.h(8)),
              itemBuilder: (_, i) {
                final p = _products[i];
                return GlassCard(
                  padding: EdgeInsets.all(r.w(12)),
                  child: ListTile(
                    leading: ProductThumbnail(
                      imagePath: p.imagePath,
                      size: r.w(44),
                      iconColor: p.isActive
                          ? AppColors.corporateBlue
                          : AppColors.greyMedium,
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: p.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      '${Fmt.money(p.price)}${p.sku != null ? ' • ${p.sku}' : ''} • คงเหลือ ${p.currentQty}',
                      style: TextStyle(
                        color: p.isLowStock ? AppColors.danger : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          onPressed: () => _showEditor(product: p),
                        ),
                        Switch(
                          value: p.isActive,
                          onChanged: (v) async {
                            await _repo.setActive(p.id!, v);
                            await _load();
                          },
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

class _ProductEditorContent extends StatefulWidget {
  final Product? product;

  const _ProductEditorContent({super.key, this.product});

  @override
  State<_ProductEditorContent> createState() => _ProductEditorContentState();
}

class _ProductEditorContentState extends State<_ProductEditorContent> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _stockCtrl;
  String? _imagePath;
  bool _removeImage = false;
  bool _picking = false;
  int? _imageBytes;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _priceCtrl = TextEditingController(
      text: widget.product?.price.toStringAsFixed(2) ?? '',
    );
    _skuCtrl = TextEditingController(text: widget.product?.sku ?? '');
    _stockCtrl = TextEditingController(
      text: widget.product == null ? '0' : '',
    );
    _imagePath = widget.product?.imagePath;
    _refreshImageSize();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _skuCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshImageSize() async {
    if (kIsWeb || _imagePath == null) {
      setState(() => _imageBytes = null);
      return;
    }
    final file = File(_imagePath!);
    if (!await file.exists()) {
      setState(() => _imageBytes = null);
      return;
    }
    final bytes = await file.length();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      ToastUtils.show(context, 'อัปโหลดรูปรองรับบนมือถือ/แท็บเล็ตเท่านั้น');
      return;
    }

    setState(() => _picking = true);
    try {
      final path = await ProductImageUtil.pickAndCompress(
        productId: widget.product?.id,
      );
      if (!mounted) return;
      if (path == null) return;

      if (_imagePath != null &&
          _imagePath != widget.product?.imagePath &&
          _imagePath!.contains('product_tmp_')) {
        await ProductImageUtil.deleteIfExists(_imagePath);
      }

      setState(() {
        _imagePath = path;
        _removeImage = false;
      });
      await _refreshImageSize();
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'บีบอัดรูปไม่สำเร็จ — ลองเลือกรูปที่เล็กกว่า');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removeImageAction() async {
    if (_imagePath != null &&
        _imagePath != widget.product?.imagePath &&
        _imagePath!.contains('product_tmp_')) {
      await ProductImageUtil.deleteIfExists(_imagePath);
    }
    setState(() {
      _imagePath = null;
      _removeImage = true;
      _imageBytes = null;
    });
  }

  _ProductEditorResult? buildResult() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (name.isEmpty || price <= 0) {
      ToastUtils.show(context, 'กรุณากรอกชื่อและราคา');
      return null;
    }

    final sku = _skuCtrl.text.trim();
    final stockQty = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    return _ProductEditorResult(
      name: name,
      price: price,
      sku: sku.isEmpty ? null : sku,
      imagePath: _removeImage ? null : _imagePath,
      removeImage: _removeImage,
      stockQty: stockQty < 0 ? 0 : stockQty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final previewPath = _removeImage ? null : _imagePath;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ProductThumbnail(
              imagePath: previewPath,
              size: r.w(72),
            ),
            SizedBox(width: r.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                    label: _picking ? 'กำลังบีบอัด...' : 'เลือกรูปสินค้า',
                    variant: ButtonVariant.outline,
                    onPressed: _picking ? null : _pickImage,
                  ),
                  if (previewPath != null) ...[
                    SizedBox(height: r.h(6)),
                    TextButton(
                      onPressed: _removeImageAction,
                      child: const Text(
                        'ลบรูป',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (_imageBytes != null) ...[
          SizedBox(height: r.h(4)),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ขนาดไฟล์ ${ProductImageUtil.formatSize(_imageBytes!)} (สูงสุด ${ProductImageUtil.formatSize(ProductImageUtil.maxBytes)})',
              style: TextStyle(
                fontSize: r.sp(9),
                color: AppColors.greyMedium,
              ),
            ),
          ),
        ],
        SizedBox(height: r.h(8)),
        Text(
          'รูปจะถูกปรับเป็น ${ProductImageUtil.maxDimension}px และบีบอัดอัตโนมัติ',
          style: TextStyle(
            fontSize: r.sp(9),
            color: AppColors.greyMedium,
          ),
        ),
        SizedBox(height: r.h(10)),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
        ),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'ราคา (บาท)'),
        ),
        TextField(
          controller: _skuCtrl,
          decoration: const InputDecoration(labelText: 'รหัส SKU (ไม่บังคับ)'),
        ),
        if (widget.product != null) ...[
          SizedBox(height: r.h(6)),
          Text(
            'สต็อกปัจจุบัน: ${widget.product!.currentQty} ชิ้น',
            style: TextStyle(
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
              color: widget.product!.isLowStock
                  ? AppColors.danger
                  : AppColors.corporateBlue,
            ),
          ),
        ],
        SizedBox(height: r.h(6)),
        TextField(
          controller: _stockCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.product == null
                ? 'สต็อกเริ่มต้น (ชิ้น)'
                : 'รับเข้าเพิ่ม (ชิ้น)',
            helperText: widget.product == null
                ? null
                : 'เว้นว่างหรือ 0 = ไม่รับเข้า',
          ),
        ),
      ],
    );
  }
}
