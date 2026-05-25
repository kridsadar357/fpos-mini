import 'product.dart';

class ProductCartLine {
  final Product product;
  int quantity;

  ProductCartLine({required this.product, this.quantity = 1});

  double get lineTotal => product.price * quantity;

  ProductCartLine copyWith({int? quantity}) => ProductCartLine(
        product: product,
        quantity: quantity ?? this.quantity,
      );
}
