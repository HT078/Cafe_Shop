import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../customer_root_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.shippingMethodLabel,
  });

  final String orderId;
  final String orderCode;
  final String shippingMethodLabel;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animate = true);
    });
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerRootScreen()),
      (_) => false,
    );
  }

  void _trackOrder() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const CustomerRootScreen(initialIndex: 3),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.charColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Đặt hàng thành công'),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  width: _animate ? 104 : 76,
                  height: _animate ? 104 : 76,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.greenAccent,
                    size: 58,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Đặt hàng thành công!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.creamColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mã đơn hàng:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  widget.orderCode.isEmpty ? widget.orderId : widget.orderCode,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.goldColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chúng tôi đã nhận được đơn hàng của bạn. Đơn hàng sẽ được xử lý trong thời gian sớm nhất.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.shippingMethodLabel} - dự kiến ${widget.shippingMethodLabel == 'Giao nhanh' ? '1-2' : '3-5'} ngày làm việc',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.creamColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _trackOrder,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Theo dõi đơn hàng'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _goHome,
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Về trang chủ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
