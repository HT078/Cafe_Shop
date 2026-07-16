import 'package:flutter/foundation.dart';

import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/supabase_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final Set<String> _busyItemKeys = {};
  String? _discountMessage;
  bool _isAgent = false;
  bool _isLoading = false;
  bool _isApplyingCoupon = false;
  String? _syncedUserId;
  _Coupon? _coupon;

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isAgent => _isAgent;

  bool get isLoading => _isLoading;

  bool get isApplyingCoupon => _isApplyingCoupon;

  bool get isBusy => _isLoading || _isApplyingCoupon || _busyItemKeys.isNotEmpty;

  int get itemCount => totalItemCount;

  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => _items.fold(
        0,
        (sum, item) => sum + item.lineTotal(isAgent: _isAgent),
      );

  String? get discountCode => _coupon?.code;

  String? get appliedCouponId => _coupon?.id;

  String? get discountMessage => _discountMessage;

  int get discountAmount {
    final coupon = _coupon;
    if (coupon == null) return 0;
    return coupon.discountFor(subtotal);
  }

  int get shippingFee {
    if (_items.isEmpty) return 0;
    final kg = _items.fold<double>(
      0,
      (sum, item) => sum + _weightToKg(item.weight) * item.quantity,
    );
    return kg <= 1 ? 20000 : 35000;
  }

  int get total => (subtotal - discountAmount + shippingFee).clamp(0, 1 << 31).toInt();

  bool isItemBusy(CartItem item) => _busyItemKeys.contains(_itemKey(item));

  void setAgentPricing(bool value) {
    if (_isAgent == value) return;
    _isAgent = value;
    _revalidateCouponLocally();
    notifyListeners();
  }

  void syncAgentPricingFromProfile(Map<String, dynamic>? profile) {
    final isAgent =
        profile?['is_agent'] == true || profile?['agent_status'] == 'approved';
    setAgentPricing(isAgent);
  }

  // Đồng bộ giỏ guest lên Supabase rồi tải lại giỏ thật của user.
  Future<void> syncWithCurrentUser({bool force = false}) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      _syncedUserId = null;
      return;
    }
    if (!force &&
        _syncedUserId == user.id &&
        _items.isNotEmpty &&
        _items.every((item) => item.id != null)) {
      return;
    }

    final guestItems = _items.where((item) => item.id == null).map((item) => item.copy()).toList();
    _isLoading = true;
    notifyListeners();

    try {
      for (final item in guestItems) {
        await SupabaseService.addCartItemQuantity(
          productId: item.product.id,
          weight: item.weight,
          grindType: item.grindType,
          quantity: item.quantity,
        );
      }

      final serverItems = await SupabaseService.fetchCartItems();
      _items
        ..clear()
        ..addAll(serverItems);
      _syncedUserId = user.id;
      _revalidateCouponLocally();
    } catch (error, stackTrace) {
      debugPrint('CartProvider.syncWithCurrentUser failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _discountMessage = 'Không đồng bộ được giỏ hàng, vui lòng thử lại';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadFromSupabase() => syncWithCurrentUser(force: true);

  Future<String?> addItem(
    Product product, {
    required String weight,
    required String grindType,
    int quantity = 1,
  }) async {
    if (quantity <= 0) return null;

    final index = _items.indexWhere((item) => item.matches(product, weight, grindType));
    final previousQuantity = index >= 0 ? _items[index].quantity : 0;
    final item = index >= 0
        ? _items[index]
        : CartItem(product: product, quantity: 0, weight: weight, grindType: grindType);

    if (index < 0) {
      _items.add(item);
    }
    item.quantity += quantity;
    _revalidateCouponLocally();
    notifyListeners();

    final user = SupabaseService.currentUser;
    if (user == null) return null;

    _setItemBusy(item, true);
    try {
      final row = await SupabaseService.addCartItemQuantity(
        productId: product.id,
        weight: weight,
        grindType: grindType,
        quantity: quantity,
      );
      item.id = row['id']?.toString();
      item.quantity = _asInt(row['quantity'], fallback: item.quantity);
      _syncedUserId = user.id;
      _revalidateCouponLocally();
      return null;
    } catch (error, stackTrace) {
      debugPrint('CartProvider.addItem failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (previousQuantity == 0) {
        _items.remove(item);
      } else {
        item.quantity = previousQuantity;
      }
      _revalidateCouponLocally();
      return 'Không lưu được giỏ hàng, vui lòng thử lại';
    } finally {
      _setItemBusy(item, false);
    }
  }

  // Thêm lại nhiều sản phẩm từ đơn hàng cũ vào giỏ.
  Future<void> addItems(List<CartItem> items) async {
    for (final item in items) {
      await addItem(
        item.product,
        weight: item.weight,
        grindType: item.grindType,
        quantity: item.quantity,
      );
    }
  }

  Future<String?> updateQuantity(CartItem item, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(item);
      return null;
    }

    _setItemBusy(item, true);
    final previousQuantity = item.quantity;
    try {
      final stock = await SupabaseService.fetchProductStock(item.product.id);
      final cappedQuantity = stock > 0 && newQuantity > stock ? stock : newQuantity;
      final message = cappedQuantity < newQuantity
          ? 'Chỉ còn $stock sản phẩm trong kho'
          : null;

      item.quantity = cappedQuantity;
      _revalidateCouponLocally();
      notifyListeners();

      if (SupabaseService.currentUser != null) {
        await SupabaseService.updateCartItemQuantity(
          cartItemId: item.id,
          productId: item.product.id,
          weight: item.weight,
          grindType: item.grindType,
          quantity: cappedQuantity,
        );
      }
      return message;
    } catch (error, stackTrace) {
      debugPrint('CartProvider.updateQuantity failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      item.quantity = previousQuantity;
      _revalidateCouponLocally();
      notifyListeners();
      return 'Không cập nhật được số lượng';
    } finally {
      _setItemBusy(item, false);
    }
  }

  Future<String?> removeFromCart(CartItem item) async {
    final index = _items.indexOf(item);
    if (index < 0) return null;

    _items.removeAt(index);
    _revalidateCouponLocally();
    notifyListeners();

    if (SupabaseService.currentUser == null) return null;

    _setItemBusy(item, true);
    try {
      await SupabaseService.deleteCartItem(
        cartItemId: item.id,
        productId: item.product.id,
        weight: item.weight,
        grindType: item.grindType,
      );
      return null;
    } catch (error, stackTrace) {
      debugPrint('CartProvider.removeFromCart failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final restoreIndex = index > _items.length ? _items.length : index;
      _items.insert(restoreIndex, item);
      _revalidateCouponLocally();
      notifyListeners();
      return 'Không xóa được sản phẩm, vui lòng thử lại';
    } finally {
      _setItemBusy(item, false);
    }
  }

  Future<String?> increment(CartItem item) => updateQuantity(item, item.quantity + 1);

  Future<String?> decrement(CartItem item) => updateQuantity(item, item.quantity - 1);

  Future<String?> remove(CartItem item) => removeFromCart(item);

  Future<bool> applyDiscountCode(String code) async {
    final normalized = code.trim().toUpperCase();
    _isApplyingCoupon = true;
    notifyListeners();

    try {
      final row = await SupabaseService.fetchCouponByCode(normalized);
      if (row == null) {
        _coupon = null;
        _discountMessage = 'Mã giảm giá không hợp lệ';
        return false;
      }

      final coupon = _Coupon.fromMap(row);
      final now = DateTime.now();
      if ((coupon.startAt != null && coupon.startAt!.isAfter(now)) ||
          (coupon.endAt != null && coupon.endAt!.isBefore(now))) {
        _coupon = null;
        _discountMessage = 'Mã đã hết hạn';
        return false;
      }

      if (subtotal < coupon.minOrderValue) {
        _coupon = null;
        _discountMessage =
            'Đơn hàng cần tối thiểu ${_formatMoney(coupon.minOrderValue)} để dùng mã này';
        return false;
      }

      if (coupon.isAgentOnly && !_isAgent) {
        _coupon = null;
        _discountMessage = 'Mã chỉ dành cho khách sỉ';
        return false;
      }

      if (coupon.usageLimit != null && coupon.usedCount >= coupon.usageLimit!) {
        _coupon = null;
        _discountMessage = 'Mã đã hết lượt sử dụng';
        return false;
      }

      _coupon = coupon;
      _discountMessage = 'Đã áp dụng mã ${coupon.code}: -${_formatMoney(discountAmount)}';
      return true;
    } catch (error, stackTrace) {
      debugPrint('CartProvider.applyDiscountCode failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _coupon = null;
      _discountMessage = 'Không kiểm tra được mã giảm giá';
      return false;
    } finally {
      _isApplyingCoupon = false;
      notifyListeners();
    }
  }

  Future<void> markCouponUsed() async {
    final couponId = _coupon?.id;
    if (couponId == null || couponId.isEmpty) return;
    await SupabaseService.incrementCouponUsage(couponId);
  }

  void removeDiscountCode() {
    _coupon = null;
    _discountMessage = null;
    notifyListeners();
  }

  Future<void> clearCart() async {
    if (SupabaseService.currentUser != null) {
      await SupabaseService.clearCartItems();
    }
    clear();
  }

  void clear() {
    _items.clear();
    _coupon = null;
    _discountMessage = null;
    _busyItemKeys.clear();
    _isLoading = false;
    _isApplyingCoupon = false;
    _syncedUserId = null;
    notifyListeners();
  }

  void _setItemBusy(CartItem item, bool value) {
    final key = _itemKey(item);
    if (value) {
      _busyItemKeys.add(key);
    } else {
      _busyItemKeys.remove(key);
    }
    notifyListeners();
  }

  String _itemKey(CartItem item) => '${item.product.id}|${item.weight}|${item.grindType}';

  void _revalidateCouponLocally() {
    final coupon = _coupon;
    if (coupon == null) return;
    if (subtotal < coupon.minOrderValue) {
      _coupon = null;
      _discountMessage =
          'Đơn hàng cần tối thiểu ${_formatMoney(coupon.minOrderValue)} để dùng mã này';
      return;
    }
    _discountMessage = 'Đã áp dụng mã ${coupon.code}: -${_formatMoney(discountAmount)}';
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _weightToKg(String weight) {
    final normalized = weight.toLowerCase().replaceAll(',', '.');
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(normalized);
    final value = double.tryParse(match?.group(1) ?? '') ?? 0.5;
    return normalized.contains('kg') ? value : value / 1000;
  }

  String _formatMoney(int value) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$textđ';
  }
}

class _Coupon {
  const _Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    required this.maxDiscount,
    required this.isAgentOnly,
    required this.isActive,
    required this.usedCount,
    this.usageLimit,
    this.startAt,
    this.endAt,
  });

  final String id;
  final String code;
  final String discountType;
  final int discountValue;
  final int minOrderValue;
  final int? maxDiscount;
  final bool isAgentOnly;
  final bool isActive;
  final int usedCount;
  final int? usageLimit;
  final DateTime? startAt;
  final DateTime? endAt;

  factory _Coupon.fromMap(Map<String, dynamic> map) {
    return _Coupon(
      id: map['id']?.toString() ?? '',
      code: (map['code'] ?? '').toString().toUpperCase(),
      discountType: (map['discount_type'] ?? 'percent').toString(),
      discountValue: _readInt(map['discount_value']),
      minOrderValue: _readInt(map['min_order_value']),
      maxDiscount: _readNullableInt(map['max_discount']),
      isAgentOnly: map['is_agent_only'] == true,
      isActive: map['is_active'] != false,
      usedCount: _readInt(map['used_count']),
      usageLimit: _readNullableInt(map['usage_limit']),
      startAt: _readDate(map['start_at']),
      endAt: _readDate(map['end_at']),
    );
  }

  int discountFor(int subtotal) {
    if (!isActive || subtotal <= 0) return 0;
    final raw = discountType == 'fixed'
        ? discountValue
        : (subtotal * discountValue / 100).round();
    final capped = maxDiscount == null ? raw : raw.clamp(0, maxDiscount!);
    return capped.clamp(0, subtotal).toInt();
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    return _readInt(value);
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
