import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../features/payment/payment_totals.dart';
import '../../../providers/cart_provider.dart';
import '../../../theme/theme.dart';
import '../customer_root_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.totalAmount,
    required this.paymentMethodLabel,
    this.isPaid = true,
    this.subtotal = 0,
    this.shippingFee = 0,
    this.discount = 0,
  });

  final String orderId;
  final String orderCode;
  final int totalAmount;
  final String paymentMethodLabel;
  final bool isPaid;
  final int subtotal;
  final int shippingFee;
  final int discount;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _goHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _money(int value) => '${_currency.format(value)}đ';

  String get _displayCode {
    final code = widget.orderCode.trim().isNotEmpty
        ? widget.orderCode.trim()
        : widget.orderId.replaceAll('-', '').toUpperCase();
    if (code.length <= 8) return code;
    return code.substring(0, 8);
  }

  void _goHome() {
    if (!mounted || _leaving) return;
    _leaving = true;
    context.read<CartProvider>().clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerRootScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(PaymentPalette.background),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Hoàn tất đơn hàng'),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.greenAccent, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.greenAccent,
                        size: 66,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 420.ms)
                    .scale(
                      begin: const Offset(0.55, 0.55),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                      duration: 520.ms,
                    ),
                const SizedBox(height: 24),
                Text(
                  'Đặt hàng thành công!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.lightTextColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'Mã đơn: #$_displayCode',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(PaymentPalette.gold),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                _SuccessSummary(
                  subtotal: widget.subtotal,
                  shippingFee: widget.shippingFee,
                  discount: widget.discount,
                  totalAmount: widget.totalAmount,
                  paymentMethodLabel: widget.paymentMethodLabel,
                  isPaid: widget.isPaid,
                  money: _money,
                ),
                const SizedBox(height: 18),
                Text(
                  'Tự động về trang chủ sau 3 giây.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _goHome,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Về trang chủ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessSummary extends StatelessWidget {
  const _SuccessSummary({
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.totalAmount,
    required this.paymentMethodLabel,
    required this.isPaid,
    required this.money,
  });

  final int subtotal;
  final int shippingFee;
  final int discount;
  final int totalAmount;
  final String paymentMethodLabel;
  final bool isPaid;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(label: 'Tiền hàng', value: money(subtotal)),
            _SummaryRow(label: 'Phí ship', value: money(shippingFee)),
            _SummaryRow(
              label: 'Giảm giá',
              value: discount > 0 ? '-${money(discount)}' : '0đ',
            ),
            const Divider(height: 22),
            _SummaryRow(
              label: isPaid
                  ? 'Số tiền đã thanh toán'
                  : 'Thanh toán khi nhận hàng',
              value: money(totalAmount),
              isTotal: true,
            ),
            _SummaryRow(label: 'Phương thức', value: paymentMethodLabel),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? AppTheme.creamColor : AppTheme.mutedColor,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal
                  ? const Color(PaymentPalette.gold)
                  : AppTheme.creamColor,
              fontWeight: FontWeight.w900,
              fontSize: isTotal ? 18 : null,
            ),
          ),
        ],
      ),
    );
  }
}
