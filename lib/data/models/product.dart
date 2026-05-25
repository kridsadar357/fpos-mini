class Product {
  final int? id;
  final String name;
  final double price;
  final String? sku;
  final String? imagePath;
  final int currentQty;
  final bool isActive;

  const Product({
    this.id,
    required this.name,
    required this.price,
    this.sku,
    this.imagePath,
    this.currentQty = 0,
    this.isActive = true,
  });

  bool get isLowStock => currentQty <= 5;

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        price: (m['price'] as num).toDouble(),
        sku: m['sku'] as String?,
        imagePath: m['image_path'] as String?,
        currentQty: (m['current_qty'] as num?)?.toInt() ?? 0,
        isActive: (m['is_active'] as int) == 1,
      );

  Product copyWith({
    int? id,
    String? name,
    double? price,
    String? sku,
    String? imagePath,
    int? currentQty,
    bool? isActive,
    bool clearImage = false,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        sku: sku ?? this.sku,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        currentQty: currentQty ?? this.currentQty,
        isActive: isActive ?? this.isActive,
      );
}
