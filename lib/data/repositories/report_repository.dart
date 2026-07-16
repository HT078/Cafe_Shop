import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';

class ReportRepository {
  const ReportRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<ReportData> fetchReport(DateTimeRange range) async {
    SupabaseService.ensureConfigured();
    await AdminService.requireAdmin();

    final start = _startOfDay(range.start);
    final end = _startOfDay(range.end);
    final endExclusive = end.add(const Duration(days: 1));
    final rows = await _fetchOrders(start, endExclusive);

    var deliveredOrders = 0;
    var cancelledOrders = 0;
    var pendingOrders = 0;
    var totalRevenue = 0;
    var wholesaleRevenue = 0;
    var retailRevenue = 0;

    final revenueByDay = <DateTime, RevenueByDay>{
      for (final day in _daysBetween(start, end))
        day: RevenueByDay(day: day, revenue: 0, orderCount: 0),
    };
    final paymentRevenue = <String, int>{};
    final categoryRevenue = <String, int>{};
    final productStats = <String, _MutableProductStats>{};

    for (final rawOrder in rows) {
      final order = Map<String, dynamic>.from(rawOrder);
      final status = (order['status'] ?? '').toString();
      final delivered = _isDeliveredStatus(status);
      final cancelled = _isCancelledStatus(status);
      final total = _asInt(order['total']);

      if (delivered) {
        deliveredOrders++;
        totalRevenue += total;
        final isWholesale = order['is_wholesale'] == true;
        if (isWholesale) {
          wholesaleRevenue += total;
        } else {
          retailRevenue += total;
        }

        final createdAt =
            DateTime.tryParse(
              order['created_at']?.toString() ?? '',
            )?.toLocal() ??
            start;
        final day = _startOfDay(createdAt);
        final currentDay =
            revenueByDay[day] ??
            RevenueByDay(day: day, revenue: 0, orderCount: 0);
        revenueByDay[day] = currentDay.copyWith(
          revenue: currentDay.revenue + total,
          orderCount: currentDay.orderCount + 1,
        );

        final method = _paymentLabel(order['payment_method']);
        paymentRevenue[method] = (paymentRevenue[method] ?? 0) + total;

        final items = order['order_items'];
        if (items is List) {
          for (final rawItem in items) {
            final item = Map<String, dynamic>.from(rawItem as Map);
            final productName = (item['product_name'] ?? 'Sản phẩm')
                .toString()
                .trim();
            final quantity = _asInt(item['quantity']);
            final lineRevenue = _asInt(item['line_total']) == 0
                ? _asInt(item['subtotal'])
                : _asInt(item['line_total']);
            final totalKg =
                _weightToKg(item['weight']?.toString() ?? '') *
                (quantity <= 0 ? 1 : quantity);

            final product = productStats.putIfAbsent(
              productName.isEmpty ? 'Sản phẩm' : productName,
              () => _MutableProductStats(
                productName.isEmpty ? 'Sản phẩm' : productName,
              ),
            );
            product.quantity += quantity;
            product.totalKg += totalKg;
            product.revenue += lineRevenue;

            final categoryName = _categoryName(item);
            categoryRevenue[categoryName] =
                (categoryRevenue[categoryName] ?? 0) + lineRevenue;
          }
        }
      } else if (cancelled) {
        cancelledOrders++;
      } else {
        pendingOrders++;
      }
    }

    final topProducts =
        productStats.values
            .map(
              (item) => TopProduct(
                productName: item.name,
                totalQuantity: item.quantity,
                totalKg: item.totalKg,
                totalRevenue: item.revenue,
              ),
            )
            .toList()
          ..sort((a, b) {
            final quantityCompare = b.totalQuantity.compareTo(a.totalQuantity);
            if (quantityCompare != 0) return quantityCompare;
            return b.totalRevenue.compareTo(a.totalRevenue);
          });

    final summary = ReportSummary(
      totalOrders: rows.length,
      deliveredOrders: deliveredOrders,
      cancelledOrders: cancelledOrders,
      pendingOrders: pendingOrders,
      totalRevenue: totalRevenue,
      wholesaleRevenue: wholesaleRevenue,
      retailRevenue: retailRevenue,
      avgOrderValue: deliveredOrders == 0
          ? 0
          : (totalRevenue / deliveredOrders).round(),
    );

    return ReportData(
      summary: summary,
      revenueByDay: revenueByDay.values.toList()
        ..sort((a, b) => a.day.compareTo(b.day)),
      topProducts: topProducts.take(10).toList(),
      revenueByPaymentMethod: _sortedMap(paymentRevenue),
      revenueByCategory: _sortedMap(categoryRevenue),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchOrders(
    DateTime start,
    DateTime endExclusive,
  ) async {
    try {
      final rows = await _client
          .from('orders')
          .select(
            'id,total,status,created_at,payment_method,is_wholesale,'
            'order_items(product_id,product_name,quantity,weight,line_total,subtotal,'
            'products(categories(title,name)))',
          )
          .gte('created_at', start.toIso8601String())
          .lt('created_at', endExclusive.toIso8601String())
          .order('created_at');
      return rows
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList();
    } on PostgrestException {
      final rows = await _client
          .from('orders')
          .select(
            'id,total,status,created_at,payment_method,is_wholesale,'
            'order_items(product_id,product_name,quantity,weight,line_total,subtotal)',
          )
          .gte('created_at', start.toIso8601String())
          .lt('created_at', endExclusive.toIso8601String())
          .order('created_at');
      return rows
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList();
    }
  }

  static Map<String, int> _sortedMap(Map<String, int> input) {
    final entries = input.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static Iterable<DateTime> _daysBetween(DateTime start, DateTime end) sync* {
    var cursor = _startOfDay(start);
    final last = _startOfDay(end);
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  static bool _isDeliveredStatus(String status) {
    final key = status.trim().toLowerCase();
    return key == 'đã giao' ||
        key == 'hoàn tất' ||
        key == 'delivered' ||
        key == 'completed';
  }

  static bool _isCancelledStatus(String status) {
    final key = status.trim().toLowerCase();
    return key.contains('hủy') || key.contains('huy') || key.contains('cancel');
  }

  static String _paymentLabel(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return 'Khác';
    final key = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (key.contains('cod') || key.contains('cash')) return 'COD';
    if (key.contains('vietqr') || key.contains('bank')) return 'VietQR';
    if (key.contains('momo')) return 'Momo';
    if (key.contains('zalo')) return 'ZaloPay';
    return raw;
  }

  static String _categoryName(Map<String, dynamic> item) {
    final product = item['products'];
    if (product is Map) {
      final category = product['categories'];
      if (category is Map) {
        final title = category['title']?.toString().trim();
        if (title != null && title.isNotEmpty) return title;
        final name = category['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
      final categoryName = product['category_name']?.toString().trim();
      if (categoryName != null && categoryName.isNotEmpty) {
        return categoryName;
      }
    }
    return 'Khác';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _weightToKg(String weight) {
    final lower = weight.toLowerCase();
    final value =
        double.tryParse(
          RegExp(
                r'\d+([.,]\d+)?',
              ).firstMatch(lower)?.group(0)?.replaceAll(',', '.') ??
              '',
        ) ??
        0;
    if (value <= 0) return 0;
    if (lower.contains('kg')) return value;
    if (lower.contains('g')) return value / 1000;
    return 0;
  }
}

class ReportData {
  const ReportData({
    required this.summary,
    required this.revenueByDay,
    required this.topProducts,
    required this.revenueByPaymentMethod,
    required this.revenueByCategory,
  });

  final ReportSummary summary;
  final List<RevenueByDay> revenueByDay;
  final List<TopProduct> topProducts;
  final Map<String, int> revenueByPaymentMethod;
  final Map<String, int> revenueByCategory;

  static const empty = ReportData(
    summary: ReportSummary.empty,
    revenueByDay: [],
    topProducts: [],
    revenueByPaymentMethod: {},
    revenueByCategory: {},
  );
}

class RevenueByDay {
  const RevenueByDay({
    required this.day,
    required this.revenue,
    required this.orderCount,
  });

  final DateTime day;
  final int revenue;
  final int orderCount;

  RevenueByDay copyWith({int? revenue, int? orderCount}) {
    return RevenueByDay(
      day: day,
      revenue: revenue ?? this.revenue,
      orderCount: orderCount ?? this.orderCount,
    );
  }
}

class TopProduct {
  const TopProduct({
    required this.productName,
    required this.totalQuantity,
    required this.totalKg,
    required this.totalRevenue,
  });

  final String productName;
  final int totalQuantity;
  final double totalKg;
  final int totalRevenue;
}

class ReportSummary {
  const ReportSummary({
    required this.totalOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
    required this.pendingOrders,
    required this.totalRevenue,
    required this.wholesaleRevenue,
    required this.retailRevenue,
    required this.avgOrderValue,
  });

  static const empty = ReportSummary(
    totalOrders: 0,
    deliveredOrders: 0,
    cancelledOrders: 0,
    pendingOrders: 0,
    totalRevenue: 0,
    wholesaleRevenue: 0,
    retailRevenue: 0,
    avgOrderValue: 0,
  );

  final int totalOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final int pendingOrders;
  final int totalRevenue;
  final int wholesaleRevenue;
  final int retailRevenue;
  final int avgOrderValue;

  double get successRate {
    if (totalOrders == 0) return 0;
    return deliveredOrders / totalOrders * 100;
  }
}

class _MutableProductStats {
  _MutableProductStats(this.name);

  final String name;
  int quantity = 0;
  double totalKg = 0;
  int revenue = 0;
}
