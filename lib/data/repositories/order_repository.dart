import '../../models/cart_item_model.dart';
import '../../services/supabase_service.dart';

class OrderRepository {
  const OrderRepository();

  Future<CheckoutOrderResult> placeOrder({
    required List<CartItem> cartItems,
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
    required String shippingMethod,
    required int shippingFee,
    required String paymentMethod,
    required int subtotal,
    required int discountAmount,
    required int total,
    required bool isAgent,
    String? voucherCode,
    String? note,
  }) {
    return SupabaseService.createCheckoutOrder(
      items: cartItems,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      shippingAddress: shippingAddress,
      shippingMethod: shippingMethod,
      shippingFee: shippingFee,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      discountAmount: discountAmount,
      total: total,
      isAgent: isAgent,
      voucherCode: voucherCode,
      note: note,
    );
  }
}
