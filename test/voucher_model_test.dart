import 'package:flutter_application_1/models/voucher_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Voucher', () {
    test('maps the coupons schema used by CartProvider', () {
      final voucher = Voucher.fromJson({
        'id': 'voucher-1',
        'code': ' haitin10 ',
        'discount_type': 'percent',
        'discount_value': 10,
        'min_order_value': 200000,
        'max_discount': 50000,
        'usage_limit': 100,
        'used_count': 12,
        'is_agent_only': true,
        'is_active': true,
        'start_at': '2026-01-01T00:00:00Z',
        'end_at': '2027-01-01T23:59:59Z',
        'description': 'Khuyến mãi đầu năm',
      });

      expect(voucher.code, 'HAITIN10');
      expect(voucher.maxUses, 100);
      expect(voucher.usedCount, 12);
      expect(voucher.maxDiscount, 50000);
      expect(voucher.isAgentOnly, isTrue);
      expect(voucher.expiresAt, isNotNull);
    });

    test('writes a payload compatible with the coupons table', () {
      final voucher = Voucher(
        code: ' haitin50 ',
        discountType: 'fixed',
        discountValue: 50000,
        minOrderValue: 300000,
        maxUses: 20,
        description: 'Giảm trực tiếp',
      );

      final payload = voucher.toJson();

      expect(payload['code'], 'HAITIN50');
      expect(payload['usage_limit'], 20);
      expect(payload.containsKey('max_uses'), isFalse);
      expect(payload.containsKey('expires_at'), isFalse);
      expect(payload['description'], 'Giảm trực tiếp');
    });

    test('does not include code in an update payload', () {
      const voucher = Voucher(
        code: 'LOCKEDCODE',
        discountType: 'percent',
        discountValue: 15,
      );

      expect(voucher.toJson(includeCode: false).containsKey('code'), isFalse);
    });

    test('reports disabled, expired and full statuses', () {
      const disabled = Voucher(
        code: 'OFF',
        discountType: 'percent',
        discountValue: 10,
        isActive: false,
      );
      final expired = Voucher(
        code: 'OLD',
        discountType: 'percent',
        discountValue: 10,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      const full = Voucher(
        code: 'FULL',
        discountType: 'fixed',
        discountValue: 10000,
        maxUses: 5,
        usedCount: 5,
      );

      expect(disabled.status, VoucherStatus.disabled);
      expect(expired.status, VoucherStatus.expired);
      expect(full.status, VoucherStatus.full);
    });
  });
}
