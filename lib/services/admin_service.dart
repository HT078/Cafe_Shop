import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class AdminStats {
  const AdminStats({
    required this.pendingToday,
    required this.revenueToday,
    required this.lowStockCount,
  });

  final int pendingToday;
  final int revenueToday;
  final int lowStockCount;
}

class SalesReportData {
  const SalesReportData({
    required this.totalKg,
    required this.totalRevenue,
    required this.revenueByDay,
    required this.topProducts,
  });

  final double totalKg;
  final int totalRevenue;
  final Map<DateTime, int> revenueByDay;
  final List<Map<String, dynamic>> topProducts;
}

class AdminService {
  AdminService._();

  static SupabaseClient get _client => SupabaseService.client;

  // Lấy role từ profile hiện tại để bảo vệ khu vực admin.
  static Future<String> currentRole() async {
    final user = SupabaseService.currentUser;
    if (user == null) return 'guest';
    final row = await _client.from('profiles').select('role').eq('id', user.id).maybeSingle();
    final role = (row?['role'] ?? 'customer').toString().trim().toLowerCase();
    debugPrint(
      'AdminService.currentRole: user=${user.id} email=${user.email} '
      'rawRole=${row?['role']} normalizedRole=$role row=$row',
    );
    return role.isEmpty ? 'customer' : role;
  }

  static Future<bool> isAdmin() async => await currentRole() == 'admin';

  static Future<void> requireAdmin() async {
    if (!await isAdmin()) {
      throw const AuthException('Không có quyền truy cập');
    }
  }

  // Thống kê nhanh cho trang tổng quan.
  static Future<AdminStats> fetchStats() async {
    await requireAdmin();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final orders = await _client
        .from('orders')
        .select('status,total,created_at')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());
    final products = await _client.from('products').select('stock,low_stock_threshold');

    final pending = orders.where((row) => row['status'] == 'Chờ duyệt').length;
    final revenue = orders.where((row) => row['status'] == 'Đã giao').fold<int>(
          0,
          (sum, row) => sum + _asInt(row['total']),
        );
    final lowStock = products.where((row) {
      final stock = _asInt(row['stock']);
      final threshold = _asInt(row['low_stock_threshold']);
      return stock > 0 && stock < (threshold == 0 ? 5 : threshold);
    }).length;

    return AdminStats(pendingToday: pending, revenueToday: revenue, lowStockCount: lowStock);
  }

  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    await requireAdmin();
    final rows = await _client.from('products').select().order('name');
    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchBanners() async {
    await requireAdmin();
    final rows = await _client.from('banners').select().order('sort_order');
    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> saveBanner(Map<String, dynamic> data, {String? id}) async {
    await requireAdmin();
    final payload = Map<String, dynamic>.from(data);
    payload['sort_order'] = _asInt(payload['sort_order']);
    payload['is_active'] = payload['is_active'] == true;

    if (id == null) {
      await _client.from('banners').insert(payload);
    } else {
      await _client.from('banners').update(payload).eq('id', id);
    }
  }

  static Future<String> uploadBannerImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await requireAdmin();
    final path = 'banners/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('banner-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('banner-images').getPublicUrl(path);
  }

  static Future<void> toggleBannerActive(String id, bool value) async {
    await requireAdmin();
    await _client.from('banners').update({
      'is_active': value,
    }).eq('id', id);
  }

  static Future<void> saveProduct(Map<String, dynamic> data, {String? id}) async {
    await requireAdmin();
    final payload = Map<String, dynamic>.from(data);
    final stock = _asInt(payload['stock']);
    payload['is_active'] = stock > 0 && payload['is_active'] != false;

    try {
      await _writeProductPayload(payload, id: id);
    } on PostgrestException catch (error) {
      final isMissingImageUrls = error.message.contains('image_urls') ||
          error.details.toString().contains('image_urls') ||
          error.code == 'PGRST204';
      if (!isMissingImageUrls || !payload.containsKey('image_urls')) rethrow;

      final fallbackPayload = Map<String, dynamic>.from(payload);
      final imageUrls = fallbackPayload.remove('image_urls');
      if (imageUrls is List && imageUrls.isNotEmpty) {
        fallbackPayload['image_url'] = imageUrls.first.toString();
      }
      await _writeProductPayload(fallbackPayload, id: id);
    }
  }

  static Future<void> _writeProductPayload(Map<String, dynamic> payload, {String? id}) async {
    if (id == null) {
      await _client.from('products').insert(payload);
    } else {
      await _client.from('products').update(payload).eq('id', id);
    }
  }

  static Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await requireAdmin();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'products/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  static Stream<List<Map<String, dynamic>>> ordersStream(String status) {
    final stream = _client.from('orders').stream(primaryKey: ['id']).order('created_at');
    return stream.map((rows) {
      return rows
          .where((row) => status == 'Tất cả' || row['status'] == status)
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList()
          .reversed
          .toList();
    });
  }

  static Future<List<Map<String, dynamic>>> fetchOrderItems(String orderId) async {
    await requireAdmin();
    final rows = await _client.from('order_items').select().eq('order_id', orderId);
    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? trackingCode,
    String? shippingUnit,
    String? cancelReason,
  }) async {
    await requireAdmin();
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (trackingCode != null) {
      payload['tracking_code'] = trackingCode;
    }
    if (shippingUnit != null) {
      payload['shipping_unit'] = shippingUnit;
    }
    if (cancelReason != null) {
      payload['cancel_reason'] = cancelReason;
    }
    await _client.from('orders').update(payload).eq('id', orderId);
  }

  static Future<void> markDelivered(String orderId) async {
    await requireAdmin();
    final order = await _client.from('orders').select('stock_checked_at').eq('id', orderId).maybeSingle();
    if (order?['stock_checked_at'] == null) {
      final items = await fetchOrderItems(orderId);
      for (final item in items) {
        final productId = item['product_id'];
        if (productId == null) continue;
        final product = await _client.from('products').select('stock').eq('id', productId).maybeSingle();
        final nextStock = (_asInt(product?['stock']) - _asInt(item['quantity'])).clamp(0, 1 << 31);
        await _client.from('products').update({
          'stock': nextStock,
          'is_active': nextStock > 0,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', productId);
      }
    }

    await _client.from('orders').update({
      'status': 'Đã giao',
      'stock_checked_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  static Future<List<Map<String, dynamic>>> fetchAgents(String status) async {
    await requireAdmin();
    final rows = await _client
        .from('profiles')
        .select('id,full_name,phone,email,agent_status,reject_reason')
        .eq('agent_status', status)
        .order('updated_at', ascending: false);
    return rows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> approveAgent(String id) async {
    await requireAdmin();
    await _client.from('profiles').update({
      'agent_status': 'approved',
      'is_agent': true,
      'reject_reason': null,
      'agent_approved_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> rejectAgent(String id, String reason) async {
    await requireAdmin();
    await _client.from('profiles').update({
      'agent_status': 'rejected',
      'is_agent': false,
      'reject_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> revokeAgent(String id) async {
    await requireAdmin();
    await _client.from('profiles').update({
      'agent_status': 'rejected',
      'is_agent': false,
      'reject_reason': 'Đã thu hồi quyền khách sỉ',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<SalesReportData> salesReport(DateTime start, DateTime end) async {
    await requireAdmin();
    final orders = await _client
        .from('orders')
        .select('id,total,created_at,order_items(product_id,product_name,quantity,weight,line_total)')
        .eq('status', 'Đã giao')
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());

    var totalRevenue = 0;
    var totalKg = 0.0;
    final revenueByDay = <DateTime, int>{};
    final productStats = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      final created = DateTime.tryParse(order['created_at']?.toString() ?? '') ?? start;
      final day = DateTime(created.year, created.month, created.day);
      final total = _asInt(order['total']);
      totalRevenue += total;
      revenueByDay[day] = (revenueByDay[day] ?? 0) + total;

      final items = order['order_items'];
      if (items is List) {
        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw);
          final name = (item['product_name'] ?? 'Sản phẩm').toString();
          final quantity = _asInt(item['quantity']);
          final kg = _weightToKg((item['weight'] ?? '').toString()) * quantity;
          totalKg += kg;
          final current = productStats.putIfAbsent(name, () => {'name': name, 'quantity': 0, 'revenue': 0});
          current['quantity'] = _asInt(current['quantity']) + quantity;
          current['revenue'] = _asInt(current['revenue']) + _asInt(item['line_total']);
        }
      }
    }

    final topProducts = productStats.values.toList()
      ..sort((a, b) => _asInt(b['quantity']).compareTo(_asInt(a['quantity'])));

    return SalesReportData(
      totalKg: totalKg,
      totalRevenue: totalRevenue,
      revenueByDay: revenueByDay,
      topProducts: topProducts.take(5).toList(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _weightToKg(String weight) {
    final lower = weight.toLowerCase();
    final number = double.tryParse(RegExp(r'\d+(\.\d+)?').firstMatch(lower)?.group(0) ?? '0') ?? 0;
    if (lower.contains('kg')) return number;
    if (lower.contains('g')) return number / 1000;
    return 0;
  }
}
