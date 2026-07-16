import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item_model.dart';
import '../../services/supabase_service.dart';
import 'payment_totals.dart';

class PaymentOrderResult {
  const PaymentOrderResult({required this.id, required this.code});

  final String id;
  final String code;
}

class PaymentState {
  const PaymentState({required this.status, this.reference});

  final String status;
  final String? reference;

  bool get isPaid => status.trim().toLowerCase() == 'paid';
}

class PaymentOrderService {
  const PaymentOrderService();

  Future<PaymentOrderResult> createOrder({
    required List<CartItem> items,
    required PaymentTotals totals,
    required PaymentMethod method,
    required bool isAgent,
    required String orderCode,
    String? recipientName,
    String? recipientPhone,
    String? shippingAddress,
    String? note,
  }) async {
    SupabaseService.ensureConfigured();
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để đặt hàng');
    }
    if (items.isEmpty) {
      throw const AuthException('Giỏ hàng đang trống');
    }

    final nowIso = DateTime.now().toIso8601String();
    final isCod = method == PaymentMethod.cod;
    final order = await _insertOrder({
      'order_code': orderCode,
      'user_id': user.id,
      'status': 'pending',
      'payment_method': method.id,
      'payment_status': isCod ? 'unpaid' : 'pending_verify',
      'subtotal': totals.subtotal,
      'shipping_fee': totals.shippingFee,
      'discount_amount': totals.discount,
      'total': totals.totalAmount,
      'total_amount': totals.totalAmount,
      'recipient_name': _blankToNull(recipientName),
      'recipient_phone': _blankToNull(recipientPhone),
      'shipping_address': _blankToNull(shippingAddress),
      'note': _blankToNull(note),
      'is_wholesale': isAgent,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    final orderId = order['id'].toString();
    await _insertOrderItems(orderId: orderId, items: items, isAgent: isAgent);

    return PaymentOrderResult(
      id: orderId,
      code: (order['order_code'] ?? orderCode).toString(),
    );
  }

  Future<PaymentState> fetchPaymentState(String orderId) async {
    final row = await SupabaseService.client
        .from('orders')
        .select('payment_status')
        .eq('id', orderId)
        .single();
    return PaymentState(
      status: (row['payment_status'] ?? 'unpaid').toString(),
    );
  }

  static String generateOrderCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>> _insertOrder(
    Map<String, dynamic> payload,
  ) async {
    var nextPayload = Map<String, dynamic>.from(payload)
      ..removeWhere((key, value) => value == null);

    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final row = await SupabaseService.client
            .from('orders')
            .insert(nextPayload)
            .select()
            .single();
        return Map<String, dynamic>.from(row);
      } on PostgrestException catch (error) {
        final missing = _missingColumnName(error);
        if (missing == null || !nextPayload.containsKey(missing)) rethrow;
        nextPayload = Map<String, dynamic>.from(nextPayload)..remove(missing);
      }
    }

    final row = await SupabaseService.client
        .from('orders')
        .insert(nextPayload)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> _insertOrderItems({
    required String orderId,
    required List<CartItem> items,
    required bool isAgent,
  }) async {
    var rows = items.map((item) {
      final unitPrice = item.unitPrice(isAgent: isAgent);
      final lineTotal = unitPrice * item.quantity;
      return <String, dynamic>{
        'order_id': orderId,
        'product_id': item.product.id,
        'product_name': item.product.name,
        'quantity': item.quantity,
        'weight': item.weight,
        'grind_type': item.grindType,
        'unit_price': unitPrice,
        'line_total': lineTotal,
        'subtotal': lineTotal,
      };
    }).toList();

    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        await SupabaseService.client.from('order_items').insert(rows);
        return;
      } on PostgrestException catch (error) {
        final missing = _missingColumnName(error);
        if (missing == null || rows.every((row) => !row.containsKey(missing))) {
          rethrow;
        }
        rows = rows
            .map((row) => Map<String, dynamic>.from(row)..remove(missing))
            .toList();
      }
    }

    await SupabaseService.client.from('order_items').insert(rows);
  }

  static String? _missingColumnName(PostgrestException error) {
    final text = '${error.message} ${error.details} ${error.hint}';
    final patterns = [
      RegExp(r'column "([^"]+)"'),
      RegExp(r"'([^']+)' column"),
      RegExp(r"Could not find the '([^']+)' column"),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String? _blankToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
