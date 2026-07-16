import '../../services/supabase_service.dart';

class PaymentAccount {
  const PaymentAccount({
    required this.method,
    required this.accountName,
    required this.accountNumber,
    required this.isActive,
    this.bankName,
    this.bankCode,
    this.qrImageUrl,
  });

  final String method;
  final String accountName;
  final String accountNumber;
  final String? bankName;
  final String? bankCode;
  final String? qrImageUrl;
  final bool isActive;

  bool get isConfigured {
    if (!isActive ||
        accountName.trim().isEmpty ||
        accountNumber.trim().isEmpty) {
      return false;
    }
    if (method == 'vietqr') return (bankCode ?? '').trim().isNotEmpty;
    return true;
  }

  String get normalizedAccountNumber =>
      accountNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  factory PaymentAccount.fromMap(Map<String, dynamic> map) {
    return PaymentAccount(
      method: (map['method'] ?? '').toString().trim().toLowerCase(),
      accountName: (map['account_name'] ?? '').toString().trim(),
      accountNumber: (map['account_number'] ?? '').toString().trim(),
      bankName: _nullableText(map['bank_name']),
      bankCode: _nullableText(map['bank_code']),
      qrImageUrl: _nullableText(map['qr_image_url']),
      isActive: map['is_active'] != false,
    );
  }

  Uri vietQrUri({required int amount, required String orderCode}) {
    final bank = (bankCode ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final account = normalizedAccountNumber;
    if (bank.isEmpty || account.isEmpty || amount <= 0) {
      throw StateError('Thông tin VietQR chưa được cấu hình đầy đủ');
    }

    return Uri.https('img.vietqr.io', '/image/$bank-$account-compact2.png', {
      'amount': '$amount',
      'addInfo': paymentTransferContent(orderCode),
      'accountName': accountName,
    });
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class PaymentInfoService {
  const PaymentInfoService();

  Future<Map<String, PaymentAccount>> fetchActiveAccounts() async {
    SupabaseService.ensureConfigured();
    final rows = await SupabaseService.client
        .from('payment_info')
        .select(
          'method,account_name,account_number,bank_name,bank_code,'
          'qr_image_url,is_active',
        )
        .eq('is_active', true)
        .order('method');

    final result = <String, PaymentAccount>{};
    for (final row in rows) {
      final account = PaymentAccount.fromMap(Map<String, dynamic>.from(row));
      if (account.method.isNotEmpty && account.isConfigured) {
        result[account.method] = account;
      }
    }
    return result;
  }
}

String paymentTransferContent(String orderCode) {
  final normalized = orderCode.toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]'),
    '',
  );
  return normalized.startsWith('DH') ? normalized : 'DH$normalized';
}
