import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import 'payment_info.dart';
import 'payment_totals.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.totalAmount,
    required this.orderCode,
    required this.money,
    required this.accounts,
    required this.isLoadingAccounts,
    required this.paymentReady,
    required this.enabled,
    required this.onChanged,
    required this.onRetry,
    this.accountError,
  });

  final PaymentMethod selected;
  final int totalAmount;
  final String orderCode;
  final String Function(int value) money;
  final Map<String, PaymentAccount> accounts;
  final bool isLoadingAccounts;
  final String? accountError;
  final bool paymentReady;
  final bool enabled;
  final ValueChanged<PaymentMethod> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isLoadingAccounts)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (accountError != null)
          _AccountError(message: accountError!, onRetry: onRetry),
        ...PaymentMethod.values.map((method) {
          final account = accounts[method.id];
          final isAvailable =
              method == PaymentMethod.cod || account?.isConfigured == true;
          final isSelected = method == selected;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(PaymentPalette.gold).withValues(alpha: 0.12)
                    : AppTheme.surfaceAltColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(PaymentPalette.gold)
                      : AppTheme.lineColor,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    enabled: enabled && isAvailable && !isLoadingAccounts,
                    onTap: enabled && isAvailable && !isLoadingAccounts
                        ? () => onChanged(method)
                        : null,
                    leading: Icon(
                      _iconFor(method),
                      color: isSelected
                          ? const Color(PaymentPalette.gold)
                          : AppTheme.mutedColor,
                    ),
                    title: Text(
                      method.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      isAvailable
                          ? method.description
                          : 'Chưa cấu hình trong Supabase',
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(PaymentPalette.gold),
                          )
                        : Icon(
                            isAvailable
                                ? Icons.circle_outlined
                                : Icons.lock_outline_rounded,
                          ),
                  ),
                  if (isSelected && isAvailable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: method != PaymentMethod.cod && !paymentReady
                          ? const _PaymentPreparationHint()
                          : PaymentMethodDetail(
                              method: method,
                              account: account,
                              totalAmount: totalAmount,
                              orderCode: orderCode,
                              money: money,
                            ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _iconFor(PaymentMethod method) => switch (method) {
    PaymentMethod.cod => Icons.payments_outlined,
    PaymentMethod.vietqr => Icons.qr_code_2_rounded,
    PaymentMethod.momo => Icons.account_balance_wallet_outlined,
    PaymentMethod.zalopay => Icons.mobile_friendly_outlined,
  };
}

class PaymentMethodDetail extends StatelessWidget {
  const PaymentMethodDetail({
    super.key,
    required this.method,
    required this.account,
    required this.totalAmount,
    required this.orderCode,
    required this.money,
  });

  final PaymentMethod method;
  final PaymentAccount? account;
  final int totalAmount;
  final String orderCode;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    return switch (method) {
      PaymentMethod.cod => _CodDetail(money: money, amount: totalAmount),
      PaymentMethod.vietqr => _VietQrDetail(
        account: account!,
        amount: totalAmount,
        orderCode: orderCode,
        money: money,
      ),
      PaymentMethod.momo => _WalletDetail(
        method: method,
        account: account!,
        amount: totalAmount,
        orderCode: orderCode,
        money: money,
      ),
      PaymentMethod.zalopay => _WalletDetail(
        method: method,
        account: account!,
        amount: totalAmount,
        orderCode: orderCode,
        money: money,
      ),
    };
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.blazeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.blazeColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.dangerColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _PaymentPreparationHint extends StatelessWidget {
  const _PaymentPreparationHint();

  @override
  Widget build(BuildContext context) {
    return const _DetailShell(
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppTheme.goldColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tạo đơn hàng để khóa đúng số tiền và hiển thị mã thanh toán.',
              style: TextStyle(color: AppTheme.lightTextColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodDetail extends StatelessWidget {
  const _CodDetail({required this.money, required this.amount});

  final String Function(int value) money;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return _DetailShell(
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: AppTheme.successColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thanh toán ${money(amount)} khi nhận hàng. Không cần quét QR.',
              style: const TextStyle(color: AppTheme.lightTextColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _VietQrDetail extends StatelessWidget {
  const _VietQrDetail({
    required this.account,
    required this.amount,
    required this.orderCode,
    required this.money,
  });

  final PaymentAccount account;
  final int amount;
  final String orderCode;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) {
      return const _DetailShell(
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa thể tạo QR vì tổng tiền đơn hàng đang là 0đ. Hãy thêm sản phẩm vào giỏ hàng.',
                style: TextStyle(color: AppTheme.lightTextColor),
              ),
            ),
          ],
        ),
      );
    }

    final content = paymentTransferContent(orderCode);
    final qrUrl = account
        .vietQrUri(amount: amount, orderCode: orderCode)
        .toString();

    return _DetailShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NetworkQrImage(url: qrUrl),
          const SizedBox(height: 14),
          _InfoLine(
            icon: Icons.account_balance,
            label: 'Ngân hàng',
            value: account.bankName ?? account.bankCode ?? '',
          ),
          _InfoLine(
            icon: Icons.credit_card,
            label: 'Số tài khoản',
            value: account.accountNumber,
          ),
          _InfoLine(
            icon: Icons.person_outline,
            label: 'Chủ tài khoản',
            value: account.accountName,
          ),
          _InfoLine(
            icon: Icons.attach_money_rounded,
            label: 'Số tiền',
            value: money(amount),
            highlight: true,
          ),
          _InfoLine(
            icon: Icons.notes_rounded,
            label: 'Nội dung',
            value: content,
            highlight: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(
                    context,
                    account.accountNumber,
                    'Đã sao chép số tài khoản',
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Sao chép STK'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(
                    context,
                    content,
                    'Đã sao chép nội dung chuyển khoản',
                  ),
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Nội dung CK'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_outlined,
                size: 17,
                color: AppTheme.successColor,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Chuyển đúng số tiền và nội dung. Hệ thống sẽ tự xác nhận khi ngân hàng báo giao dịch.',
                  style: TextStyle(color: AppTheme.mutedColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletDetail extends StatelessWidget {
  const _WalletDetail({
    required this.method,
    required this.account,
    required this.amount,
    required this.orderCode,
    required this.money,
  });

  final PaymentMethod method;
  final PaymentAccount account;
  final int amount;
  final String orderCode;
  final String Function(int value) money;

  String get _title => method == PaymentMethod.momo ? 'Momo' : 'ZaloPay';

  String get _qrData => method == PaymentMethod.momo
      ? '2|99|${account.normalizedAccountNumber}|${account.accountName}||0|0|$amount'
      : 'zalopay:${account.normalizedAccountNumber}:$amount:${paymentTransferContent(orderCode)}';

  Uri get _deeplink => Uri(
    scheme: method == PaymentMethod.momo ? 'momo' : 'zalopay',
    host: 'transfer',
    queryParameters: {
      'phone': account.normalizedAccountNumber,
      'amount': '$amount',
      'note': paymentTransferContent(orderCode),
    },
  );

  @override
  Widget build(BuildContext context) {
    return _DetailShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((account.qrImageUrl ?? '').isNotEmpty)
            _NetworkQrImage(url: account.qrImageUrl!, square: true)
          else
            _QrBox(data: _qrData),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openDeeplink(context),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text('Mở $_title'),
            ),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            icon: Icons.phone_android,
            label: 'Số $_title',
            value: account.accountNumber,
          ),
          _InfoLine(
            icon: Icons.person_outline,
            label: 'Tên',
            value: account.accountName,
          ),
          _InfoLine(
            icon: Icons.attach_money_rounded,
            label: 'Số tiền',
            value: money(amount),
            highlight: true,
          ),
          _InfoLine(
            icon: Icons.notes_rounded,
            label: 'Nội dung',
            value: paymentTransferContent(orderCode),
            highlight: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Nếu không mở được $_title, hãy chuyển thủ công theo thông tin trên.',
            style: const TextStyle(color: AppTheme.mutedColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _openDeeplink(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _deeplink,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
      _showOpenError(context);
    } catch (_) {
      if (context.mounted) _showOpenError(context);
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không mở được $_title trên thiết bị này')),
    );
  }
}

class _NetworkQrImage extends StatelessWidget {
  const _NetworkQrImage({required this.url, this.square = false});

  final String url;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: AspectRatio(
          aspectRatio: square ? 1 : 540 / 640,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Colors.white,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, _) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                errorWidget: (context, _, _) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.dangerColor,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Không tải được mã QR',
                        style: TextStyle(color: AppTheme.charColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrBox extends StatelessWidget {
  const _QrBox({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
          gapless: false,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight
                ? const Color(PaymentPalette.gold)
                : AppTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppTheme.mutedColor)),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight
                    ? const Color(PaymentPalette.gold)
                    : AppTheme.lightTextColor,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailShell extends StatelessWidget {
  const _DetailShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(PaymentPalette.background),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: child,
    );
  }
}

Future<void> _copy(
  BuildContext context,
  String value,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(confirmation)));
}
