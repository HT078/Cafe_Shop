import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/product_model.dart';

void main() {
  test('sản phẩm chưa gán danh mục dùng nhãn Chưa phân loại', () {
    final product = Product.fromMap({
      'id': 'product-1',
      'name': 'Cà phê thử nghiệm',
      'stock': 1,
    });

    expect(product.category, 'Chưa phân loại');
    expect(product.isActive, isTrue);
  });
}
