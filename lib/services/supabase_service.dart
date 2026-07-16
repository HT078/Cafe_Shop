import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address_item_model.dart';
import '../models/cart_item_model.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class CheckoutOrderResult {
  const CheckoutOrderResult({
    required this.id,
    required this.code,
    required this.shippingMethod,
  });

  final String id;
  final String code;
  final String shippingMethod;
}

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client =>
      maybeClient ??
      (throw StateError(
        'Supabase chua duoc khoi tao. Kiem tra file .env va qua trinh initialize.',
      ));

  static SupabaseClient? get maybeClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isInitialized => maybeClient != null;

  static User? get currentUser => maybeClient?.auth.currentUser;

  static bool get isConfigured {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    final uri = Uri.tryParse(url);
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('PASTE_') &&
        !key.contains('PASTE_') &&
        uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty;
  }

  static void ensureConfigured() {
    if (!isConfigured) {
      throw const AuthException(
        'Chưa cấu hình Supabase. Hãy điền SUPABASE_URL và SUPABASE_ANON_KEY trong file .env',
      );
    }
  }

  // Lấy danh mục sản phẩm từ Supabase.
  static Future<List<CategoryItem>> fetchCategories() async {
    ensureConfigured();
    List<dynamic> rows;
    try {
      rows = await client.from('categories').select().order('title');
    } on PostgrestException catch (error) {
      if (error.code != '42703' && !error.message.contains('title')) {
        rethrow;
      }
      rows = await client.from('categories').select().order('name');
    }
    return rows
        .map<CategoryItem>(
          (row) => CategoryItem.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  // Lấy sản phẩm kèm tên danh mục nếu bảng có quan hệ categories.
  static Future<List<Product>> fetchProducts() async {
    ensureConfigured();
    try {
      final rows = await client
          .from('products')
          .select('*, categories(title, name)')
          .order('name');
      return rows
          .map<Product>(
            (row) => Product.fromMap(Map<String, dynamic>.from(row)),
          )
          .toList();
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'SupabaseService.fetchProducts(join) failed: '
        'code=${error.code}, message=${error.message}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      try {
        final rows = await client
            .from('products')
            .select('*, categories(name)')
            .order('name');
        return rows
            .map<Product>(
              (row) => Product.fromMap(Map<String, dynamic>.from(row)),
            )
            .toList();
      } on PostgrestException catch (nameJoinError, nameJoinStackTrace) {
        debugPrint(
          'SupabaseService.fetchProducts(name join) failed: '
          'code=${nameJoinError.code}, message=${nameJoinError.message}, details=${nameJoinError.details}, hint=${nameJoinError.hint}',
        );
        debugPrintStack(stackTrace: nameJoinStackTrace);
        final rows = await client.from('products').select().order('name');
        return rows
            .map<Product>(
              (row) => Product.fromMap(Map<String, dynamic>.from(row)),
            )
            .toList();
      }
    }
  }

  // Lấy danh sách sản phẩm bán chạy để hiển thị ở Home.
  static Future<List<Product>> fetchBestSellers() async {
    ensureConfigured();
    late final List<dynamic> rows;
    try {
      rows = await client
          .from('products')
          .select('*, categories(title, name)')
          .eq('is_bestseller', true)
          .eq('is_active', true)
          .order('name');
    } on PostgrestException catch (error) {
      if (error.code != '42703' && !error.message.contains('title')) {
        rethrow;
      }
      rows = await client
          .from('products')
          .select('*, categories(name)')
          .eq('is_bestseller', true)
          .eq('is_active', true)
          .order('name');
    }
    return rows
        .map<Product>((row) => Product.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  // Lấy một sản phẩm theo id, dùng cho banner điều hướng.
  static Future<Product?> fetchProductById(String id) async {
    ensureConfigured();
    Map<String, dynamic>? row;
    try {
      final result = await client
          .from('products')
          .select('*, categories(title, name)')
          .eq('id', id)
          .maybeSingle();
      row = result == null ? null : Map<String, dynamic>.from(result);
    } on PostgrestException catch (error) {
      if (error.code != '42703' && !error.message.contains('title')) {
        rethrow;
      }
      final result = await client
          .from('products')
          .select('*, categories(name)')
          .eq('id', id)
          .maybeSingle();
      row = result == null ? null : Map<String, dynamic>.from(result);
    }
    if (row == null) return null;
    return Product.fromMap(row);
  }

  // Lấy profile của người dùng hiện tại.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      debugPrint('SupabaseService.fetchProfile: currentUser=null');
      return null;
    }

    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    debugPrint(
      'SupabaseService.fetchProfile: user=${user.id} '
      'email=${user.email} role=${row?['role']} raw=$row',
    );
    if (row == null) {
      debugPrint(
        'SupabaseService.fetchProfile: KHÔNG có profile cho auth.uid=${user.id}. '
        'Hãy kiểm tra profiles.id có đúng bằng auth.users.id của email ${user.email} không.',
      );
    }
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  // Lấy role của người dùng hiện tại.
  // Lấy giỏ hàng thật từ Supabase, kèm thông tin sản phẩm để UI hiển thị ngay.
  static Future<List<CartItem>> fetchCartItems() async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) return [];

    try {
      final rows = await client
          .from('cart_items')
          .select('*, products(*)')
          .eq('user_id', user.id);
      return rows
          .map<CartItem?>(
            (row) => _cartItemFromRow(Map<String, dynamic>.from(row)),
          )
          .whereType<CartItem>()
          .toList();
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'fetchCartItems(join) failed: code=${error.code} '
        'message=${error.message} details=${error.details} hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);

      final rows = await client
          .from('cart_items')
          .select()
          .eq('user_id', user.id);
      final productIds = rows
          .map((row) => row['product_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (productIds.isEmpty) return [];

      final productRows = await client
          .from('products')
          .select()
          .inFilter('id', productIds);
      final productsById = <String, Map<String, dynamic>>{
        for (final productRow in productRows)
          productRow['id'].toString(): Map<String, dynamic>.from(productRow),
      };

      return rows
          .map<CartItem?>((row) {
            final itemRow = Map<String, dynamic>.from(row);
            return _cartItemFromRow(
              itemRow,
              product: productsById[itemRow['product_id']?.toString()],
            );
          })
          .whereType<CartItem>()
          .toList();
    } catch (error, stackTrace) {
      debugPrint('fetchCartItems failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // Cộng dồn sản phẩm nếu cùng product + weight + grind_type đã tồn tại.
  static Future<Map<String, dynamic>> addCartItemQuantity({
    required String productId,
    required String weight,
    required String grindType,
    required int quantity,
  }) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để lưu giỏ hàng');
    }

    final existingRows = await client
        .from('cart_items')
        .select()
        .eq('user_id', user.id)
        .eq('product_id', productId)
        .eq('weight', weight)
        .eq('grind_type', grindType)
        .limit(1);

    if (existingRows.isNotEmpty) {
      final existing = Map<String, dynamic>.from(existingRows.first);
      final nextQuantity = _asInt(existing['quantity']) + quantity;
      final updated = await client
          .from('cart_items')
          .update({'quantity': nextQuantity})
          .eq('user_id', user.id)
          .eq('product_id', productId)
          .eq('weight', weight)
          .eq('grind_type', grindType)
          .select()
          .single();
      return Map<String, dynamic>.from(updated);
    }

    final inserted = await client
        .from('cart_items')
        .insert({
          'user_id': user.id,
          'product_id': productId,
          'weight': weight,
          'grind_type': grindType,
          'quantity': quantity,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  }

  // Cập nhật số lượng của một dòng giỏ hàng.
  static Future<void> updateCartItemQuantity({
    String? cartItemId,
    required String productId,
    required String weight,
    required String grindType,
    required int quantity,
  }) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) return;

    var query = client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('user_id', user.id);
    if (cartItemId != null && cartItemId.isNotEmpty) {
      query = query.eq('id', cartItemId);
    } else {
      query = query
          .eq('product_id', productId)
          .eq('weight', weight)
          .eq('grind_type', grindType);
    }
    await query;
  }

  // Xóa một dòng giỏ hàng theo id hoặc khóa ghép.
  static Future<void> deleteCartItem({
    String? cartItemId,
    required String productId,
    required String weight,
    required String grindType,
  }) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) return;

    var query = client.from('cart_items').delete().eq('user_id', user.id);
    if (cartItemId != null && cartItemId.isNotEmpty) {
      query = query.eq('id', cartItemId);
    } else {
      query = query
          .eq('product_id', productId)
          .eq('weight', weight)
          .eq('grind_type', grindType);
    }
    await query;
  }

  // Xóa toàn bộ giỏ hàng của user hiện tại sau khi đặt hàng thành công.
  static Future<void> clearCartItems() async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) return;
    await client.from('cart_items').delete().eq('user_id', user.id);
  }

  // Lấy tồn kho mới nhất để chặn tăng quá số lượng còn lại.
  static Future<int> fetchProductStock(String productId) async {
    ensureConfigured();
    final row = await client
        .from('products')
        .select('stock')
        .eq('id', productId)
        .maybeSingle();
    return _asInt(row?['stock']);
  }

  // Tìm coupon theo mã, không phân biệt hoa thường.
  static Future<Map<String, dynamic>?> fetchCouponByCode(String code) async {
    ensureConfigured();
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final rows = await client
        .from('coupons')
        .select()
        .ilike('code', normalized)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  // Tăng lượt dùng coupon sau khi đơn hàng được tạo thành công.
  static Future<void> incrementCouponUsage(String couponId) async {
    ensureConfigured();
    if (couponId.isEmpty) return;
    try {
      await client.rpc(
        'increment_coupon_usage',
        params: {'p_coupon_id': couponId},
      );
      return;
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'increment_coupon_usage RPC failed, fallback direct update: '
        'code=${error.code} message=${error.message} details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    final row = await client
        .from('coupons')
        .select('used_count')
        .eq('id', couponId)
        .single();
    final usedCount = _asInt(row['used_count']);
    await client
        .from('coupons')
        .update({'used_count': usedCount + 1})
        .eq('id', couponId);
  }

  static CartItem? _cartItemFromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? product,
  }) {
    final productMap =
        product ??
        (row['products'] is Map
            ? Map<String, dynamic>.from(row['products'] as Map)
            : null);
    if (productMap == null) return null;

    final parsedProduct = Product.fromMap(productMap);
    final quantity = _asInt(row['quantity']);
    return CartItem(
      id: row['id']?.toString(),
      product: parsedProduct,
      quantity: quantity <= 0 ? 1 : quantity,
      weight:
          (row['weight'] ??
                  (parsedProduct.weights.isEmpty
                      ? '500g'
                      : parsedProduct.weights.first))
              .toString(),
      grindType:
          (row['grind_type'] ??
                  (parsedProduct.grindOptions.isEmpty
                      ? 'Xay pha phin'
                      : parsedProduct.grindOptions.first))
              .toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<String> fetchCurrentRole() async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      debugPrint(
        'SupabaseService.fetchCurrentRole: currentUser=null -> customer',
      );
      return 'customer';
    }

    final row = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) {
      debugPrint(
        'SupabaseService.fetchCurrentRole: KHÔNG tìm thấy profile theo '
        'auth.uid=${user.id} email=${user.email} -> customer',
      );
      return 'customer';
    }
    final rawRole = row['role']?.toString() ?? 'customer';
    final normalizedRole = rawRole.trim().toLowerCase();
    debugPrint(
      'SupabaseService.fetchCurrentRole: user=${user.id} '
      'email=${user.email} rawRole="$rawRole" normalized="$normalizedRole"',
    );
    return normalizedRole.isEmpty ? 'customer' : normalizedRole;
  }

  // Tạo hoặc cập nhật profile sau đăng ký / Google login.
  static Future<void> upsertProfile({
    required String id,
    required String fullName,
    required String phone,
    String? email,
  }) async {
    ensureConfigured();
    await client.from('profiles').upsert({
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // Cập nhật profile theo id, dùng cho màn thông tin cá nhân và khách sỉ.
  static Future<void> updateProfileById(
    String id,
    Map<String, dynamic> values,
  ) async {
    ensureConfigured();
    await client.from('profiles').update(values).eq('id', id);
  }

  // Lấy đơn hàng theo trạng thái của user hiện tại.
  static Future<List<Map<String, dynamic>>> fetchOrdersByStatus(
    String status,
  ) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      return [];
    }

    var query = client
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', user.id);
    if (status == 'Lịch sử mua') {
      query = query.inFilter('status', ['Đã giao', 'Hoàn tất', 'Lịch sử mua']);
    } else {
      query = query.eq('status', status);
    }

    final rows = await query.order('created_at', ascending: false);
    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // Tạo đơn hàng và các dòng sản phẩm trong order_items.
  static Future<String> createOrder({
    required List<CartItem> items,
    required int subtotal,
    required int discountAmount,
    required int shippingFee,
    required int total,
  }) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để đặt hàng');
    }

    final order = await client
        .from('orders')
        .insert({
          'user_id': user.id,
          'status': 'Chờ duyệt',
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'shipping_fee': shippingFee,
          'total': total,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final orderId = order['id'].toString();
    await client
        .from('order_items')
        .insert(
          items
              .map(
                (item) => {
                  'order_id': orderId,
                  'product_id': item.product.id,
                  'product_name': item.product.name,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice(),
                  'line_total': item.lineTotal(),
                  'weight': item.weight,
                  'grind_type': item.grindType,
                },
              )
              .toList(),
        );

    return orderId;
  }

  static Future<List<Map<String, dynamic>>> _fetchOrderRowsByTab(
    String tab,
    String userId,
  ) async {
    var query = client.from('orders').select().eq('user_id', userId);

    switch (tab) {
      case 'Chờ duyệt':
        query = query.inFilter('status', ['Chờ duyệt', 'Đã xác nhận']);
        break;
      case 'Đang đóng gói':
      case 'Đang giao':
        query = query.eq('status', tab);
        break;
      case 'Lịch sử mua':
        query = query.inFilter('status', ['Đã giao', 'Hoàn tất']);
        break;
      default:
        query = query.eq('status', tab);
    }

    final rows = await query.order('created_at', ascending: false);
    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // Lấy danh sách đơn hàng theo tab hiển thị của màn khách.
  static Future<List<Map<String, dynamic>>> fetchCustomerOrdersByTab(
    String tab,
  ) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      return [];
    }

    try {
      final rows = await _fetchOrderRowsByTab(tab, user.id);
      if (rows.isEmpty) {
        return [];
      }

      final orderIds = rows
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      final itemsByOrder = <String, List<Map<String, dynamic>>>{};

      if (orderIds.isNotEmpty) {
        try {
          final itemRows = await client
              .from('order_items')
              .select()
              .inFilter('order_id', orderIds);
          for (final row in itemRows) {
            final item = Map<String, dynamic>.from(row);
            final orderId = item['order_id']?.toString();
            if (orderId == null || orderId.isEmpty) continue;
            itemsByOrder.putIfAbsent(orderId, () => []).add(item);
          }
        } on PostgrestException catch (error, stackTrace) {
          debugPrint(
            'fetchCustomerOrdersByTab($tab) order_items query failed: '
            'code=${error.code} message=${error.message} details=${error.details}',
          );
          debugPrintStack(stackTrace: stackTrace);
        } catch (error, stackTrace) {
          debugPrint(
            'fetchCustomerOrdersByTab($tab) order_items query failed: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      return rows.map((row) {
        final order = Map<String, dynamic>.from(row);
        order['order_items'] =
            itemsByOrder[order['id']?.toString()] ?? const [];
        return order;
      }).toList();
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'fetchCustomerOrdersByTab($tab) orders query failed: '
        'code=${error.code} message=${error.message} details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('fetchCustomerOrdersByTab($tab) orders query failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // Tạo đơn hàng với cờ giá sỉ để ghi đúng đơn giá order_items.
  static Future<String> createOrderWithPricing({
    required List<CartItem> items,
    required int subtotal,
    required int discountAmount,
    required int shippingFee,
    required int total,
    required bool isAgent,
  }) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để đặt hàng');
    }

    final order = await client
        .from('orders')
        .insert({
          'user_id': user.id,
          'status': 'Chờ duyệt',
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'shipping_fee': shippingFee,
          'total': total,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final orderId = order['id'].toString();
    await client
        .from('order_items')
        .insert(
          items
              .map(
                (item) => {
                  'order_id': orderId,
                  'product_id': item.product.id,
                  'product_name': item.product.name,
                  'quantity': item.quantity,
                  'unit_price': item.unitPrice(isAgent: isAgent),
                  'line_total': item.lineTotal(isAgent: isAgent),
                  'weight': item.weight,
                  'grind_type': item.grindType,
                },
              )
              .toList(),
        );

    return orderId;
  }

  // Lấy danh sách địa chỉ giao hàng của user hiện tại.
  static Future<CheckoutOrderResult> createCheckoutOrder({
    required List<CartItem> items,
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
  }) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để đặt hàng');
    }
    if (items.isEmpty) {
      throw const AuthException('Giỏ hàng đang trống');
    }

    await _ensureEnoughStock(items);

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final orderCode = _generateOrderCode(now);
    final orderPayload = <String, dynamic>{
      'order_code': orderCode,
      'user_id': user.id,
      'status': 'Chờ duyệt',
      'recipient_name': recipientName.trim(),
      'recipient_phone': recipientPhone.trim(),
      'shipping_address': shippingAddress.trim(),
      'shipping_method': shippingMethod,
      'shipping_fee': shippingFee,
      'payment_method': paymentMethod,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'total': total,
      'voucher_code': voucherCode,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'is_wholesale': isAgent,
      'stock_checked_at': nowIso,
      'created_at': nowIso,
      'updated_at': nowIso,
    }..removeWhere((key, value) => value == null);

    final order = await _insertOrderWithFallback(orderPayload);
    final orderId = order['id'].toString();
    final savedOrderCode = (order['order_code'] ?? orderCode).toString();

    await _insertOrderItemsWithFallback(
      orderId: orderId,
      items: items,
      isAgent: isAgent,
    );
    await _decreaseProductStock(items);

    return CheckoutOrderResult(
      id: orderId,
      code: savedOrderCode,
      shippingMethod: shippingMethod,
    );
  }

  static Future<void> _ensureEnoughStock(List<CartItem> items) async {
    for (final item in items) {
      final stock = await fetchProductStock(item.product.id);
      if (stock <= 0) {
        throw AuthException('Sản phẩm ${item.product.name} đã hết hàng');
      }
      if (item.quantity > stock) {
        throw AuthException(
          'Sản phẩm ${item.product.name} chỉ còn $stock trong kho',
        );
      }
    }
  }

  static Future<Map<String, dynamic>> _insertOrderWithFallback(
    Map<String, dynamic> payload,
  ) async {
    var nextPayload = Map<String, dynamic>.from(payload);
    for (var attempt = 0; attempt < 16; attempt++) {
      try {
        final row = await client
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

    final row = await client.from('orders').insert(nextPayload).select().single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> _insertOrderItemsWithFallback({
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
        'unit_price': unitPrice,
        'line_total': lineTotal,
        'subtotal': lineTotal,
        'weight': item.weight,
        'grind_type': item.grindType,
      };
    }).toList();

    for (var attempt = 0; attempt < 16; attempt++) {
      try {
        await client.from('order_items').insert(rows);
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

    await client.from('order_items').insert(rows);
  }

  static Future<void> _decreaseProductStock(List<CartItem> items) async {
    for (final item in items) {
      if (await _tryDecreaseStockRpc(item)) {
        continue;
      }

      final stock = await fetchProductStock(item.product.id);
      if (stock <= 0 || item.quantity > stock) {
        throw AuthException(
          'Sản phẩm ${item.product.name} không còn đủ hàng để đặt',
        );
      }
      final nextStock = stock - item.quantity;
      await _updateProductStockWithFallback(item.product.id, nextStock);
    }
  }

  static Future<bool> _tryDecreaseStockRpc(CartItem item) async {
    final attempts = [
      {'product_id': item.product.id, 'amount': item.quantity},
      {'p_product_id': item.product.id, 'p_quantity': item.quantity},
      {'variant_id': item.product.id, 'amount': item.quantity},
    ];

    for (final params in attempts) {
      try {
        await client.rpc('decrease_stock', params: params);
        return true;
      } on PostgrestException catch (error) {
        debugPrint(
          'decrease_stock RPC fallback: code=${error.code} message=${error.message}',
        );
      }
    }
    return false;
  }

  static Future<void> _updateProductStockWithFallback(
    String productId,
    int nextStock,
  ) async {
    var payload = <String, dynamic>{
      'stock': nextStock,
      'is_active': nextStock > 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await client.from('products').update(payload).eq('id', productId);
        return;
      } on PostgrestException catch (error) {
        final missing = _missingColumnName(error);
        if (missing == null || !payload.containsKey(missing)) rethrow;
        payload = Map<String, dynamic>.from(payload)..remove(missing);
      }
    }

    await client.from('products').update(payload).eq('id', productId);
  }

  static String _generateOrderCode(DateTime now) {
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart = (now.microsecondsSinceEpoch % 1000)
        .toString()
        .padLeft(3, '0');
    return 'HT-$datePart-$randomPart';
  }

  static String? _missingColumnName(PostgrestException error) {
    if (error.code != 'PGRST204' && error.code != '42703') return null;
    final text = '${error.message} ${error.details} ${error.hint}';
    final quoted = RegExp(r"'([^']+)'").firstMatch(text)?.group(1);
    if (quoted != null && quoted.isNotEmpty) return quoted;
    final column = RegExp(
      r'column\s+"?([A-Za-z0-9_]+)"?',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    return column;
  }

  static Future<List<AddressItem>> fetchAddresses() async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      return [];
    }

    final rows = await client
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return rows
        .map<AddressItem>(
          (row) => AddressItem.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  // Lưu địa chỉ mới hoặc cập nhật địa chỉ cũ.
  static Future<void> saveAddress(AddressItem address) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để lưu địa chỉ');
    }

    final payload = <String, dynamic>{
      ...address.toMap(),
      'user_id': user.id,
      if (address.createdAt != null)
        'created_at': address.createdAt!.toIso8601String(),
    };

    String savedId = address.id;
    if (savedId.isEmpty) {
      final inserted = await client
          .from('addresses')
          .insert(payload)
          .select('id')
          .single();
      savedId = inserted['id'].toString();
    } else {
      await client
          .from('addresses')
          .update(payload)
          .eq('id', savedId)
          .eq('user_id', user.id);
    }

    if (address.isDefault) {
      await client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', user.id)
          .neq('id', savedId);
      await client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', savedId)
          .eq('user_id', user.id);
    }
  }

  // Đặt một địa chỉ làm mặc định.
  static Future<void> setDefaultAddress(String id) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để cập nhật địa chỉ');
    }

    await client
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', user.id);
    await client
        .from('addresses')
        .update({'is_default': true})
        .eq('id', id)
        .eq('user_id', user.id);
  }

  // Xóa địa chỉ và giữ lại một địa chỉ mặc định nếu còn dữ liệu.
  static Future<void> deleteAddress(String id) async {
    ensureConfigured();
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Bạn cần đăng nhập để xóa địa chỉ');
    }

    await client.from('addresses').delete().eq('id', id).eq('user_id', user.id);

    final remaining = await client
        .from('addresses')
        .select('id')
        .eq('user_id', user.id)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false)
        .maybeSingle();
    if (remaining != null) {
      await client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', remaining['id']);
    }
  }
}
