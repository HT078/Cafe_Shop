import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';

class PaymentPalette {
  const PaymentPalette._();

  static const background = 0xFF1A0A04;
  static const gold = 0xFFBA7517;
}

class PaymentTotals {
  const PaymentTotals({
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.totalAmount,
    required this.couponApplied,
  });

  final int subtotal;
  final int shippingFee;
  final int discount;
  final int totalAmount;
  final bool couponApplied;

  static PaymentTotals fromCart(CartProvider cart, {List<CartItem>? items}) {
    final sourceItems = items ?? cart.items;
    final subtotal = sourceItems.fold<int>(
      0,
      (sum, item) => sum + item.lineTotal(isAgent: cart.isAgent),
    );
    final couponApplied = (cart.discountCode ?? '').trim().isNotEmpty;
    final shippingFee = subtotal <= 0 || subtotal >= 500000 ? 0 : 30000;
    final discount = couponApplied ? (subtotal * 0.1).round() : 0;
    final totalAmount = (subtotal + shippingFee - discount)
        .clamp(0, 1 << 31)
        .toInt();

    return PaymentTotals(
      subtotal: subtotal,
      shippingFee: shippingFee,
      discount: discount,
      totalAmount: totalAmount,
      couponApplied: couponApplied,
    );
  }
}

enum PaymentMethod {
  cod('cod', 'COD', 'Thanh toán khi nhận hàng'),
  vietqr('vietqr', 'VietQR - Ngân hàng', 'Quét QR chuyển khoản ngân hàng'),
  momo('momo', 'Momo', 'Chuyển vào ví Momo của cửa hàng'),
  zalopay('zalopay', 'ZaloPay', 'Chuyển vào ví ZaloPay của cửa hàng');

  const PaymentMethod(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  String get successLabel => switch (this) {
    PaymentMethod.cod => 'COD',
    PaymentMethod.vietqr => 'VietQR',
    PaymentMethod.momo => 'Momo',
    PaymentMethod.zalopay => 'ZaloPay',
  };
}
