import 'product_model.dart';

class CartItem {
  CartItem({
    this.id,
    required this.product,
    this.quantity = 1,
    required this.weight,
    required this.grindType,
  });

  String? id;
  final Product product;
  int quantity;
  String weight;
  String grindType;

  String get storageKey => id ?? '${product.id}|$weight|$grindType';

  bool matches(Product product, String weight, String grindType) {
    return this.product.id == product.id &&
        this.weight == weight &&
        this.grindType == grindType;
  }

  CartItem copy() {
    return CartItem(
      id: id,
      product: product,
      quantity: quantity,
      weight: weight,
      grindType: grindType,
    );
  }

  int unitPrice({bool isAgent = false}) => product.priceFor(weight, isAgent: isAgent);

  int lineTotal({bool isAgent = false}) => unitPrice(isAgent: isAgent) * quantity;
}
