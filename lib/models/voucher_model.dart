import 'package:intl/intl.dart';

enum VoucherStatus { active, disabled, scheduled, expired, full }

class Voucher {
  const Voucher({
    this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxDiscount,
    this.maxUses,
    this.usedCount = 0,
    this.isAgentOnly = false,
    this.isActive = true,
    this.startAt,
    this.expiresAt,
    this.description,
    this.createdAt,
  });

  final String? id;
  final String code;
  final String discountType;
  final int discountValue;
  final int minOrderValue;
  final int? maxDiscount;
  final int? maxUses;
  final int usedCount;
  final bool isAgentOnly;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? expiresAt;
  final String? description;
  final DateTime? createdAt;

  static final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  String get discountLabel => discountType == 'fixed'
      ? '-${formatMoney(discountValue)}'
      : '-$discountValue%';

  String get remainingLabel {
    final limit = maxUses;
    if (limit == null) return 'Không giới hạn lượt dùng';
    final remaining = (limit - usedCount).clamp(0, limit);
    return '$remaining/$limit lượt còn lại';
  }

  bool get isScheduled => startAt != null && DateTime.now().isBefore(startAt!);

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isFull => maxUses != null && usedCount >= maxUses!;

  VoucherStatus get status {
    if (!isActive) return VoucherStatus.disabled;
    if (isExpired) return VoucherStatus.expired;
    if (isFull) return VoucherStatus.full;
    if (isScheduled) return VoucherStatus.scheduled;
    return VoucherStatus.active;
  }

  static String formatMoney(int value) => '${_currency.format(value)}đ';

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id']?.toString(),
      code: (json['code'] ?? '').toString().trim().toUpperCase(),
      discountType: (json['discount_type'] ?? 'percent').toString(),
      discountValue: _readInt(json['discount_value']),
      minOrderValue: _readInt(json['min_order_value']),
      maxDiscount: _readNullableInt(json['max_discount']),
      maxUses: _readNullableInt(json['usage_limit'] ?? json['max_uses']),
      usedCount: _readInt(json['used_count']),
      isAgentOnly: json['is_agent_only'] == true,
      isActive: json['is_active'] != false,
      startAt: _readDate(json['start_at']),
      expiresAt: _readDate(json['end_at'] ?? json['expires_at']),
      description: _readNullableText(json['description']),
      createdAt: _readDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson({bool includeCode = true}) {
    return <String, dynamic>{
      if (includeCode) 'code': code.trim().toUpperCase(),
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      'max_discount': maxDiscount,
      'usage_limit': maxUses,
      'is_agent_only': isAgentOnly,
      'is_active': isActive,
      'start_at': startAt?.toUtc().toIso8601String(),
      'end_at': expiresAt?.toUtc().toIso8601String(),
      'description': _readNullableText(description),
    };
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return _readInt(value);
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String? _readNullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
