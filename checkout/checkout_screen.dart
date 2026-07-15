import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/payment/payment_order_service.dart';
import '../../../features/payment/payment_info.dart';
import '../../../features/payment/payment_totals.dart';
import '../../../features/payment/payment_widgets.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/login_gate.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.totalAmount,
    this.cartItems = const [],
    this.initialSubtotal,
    this.initialDiscount,
    this.initialShippingFee,
    this.initialTotal,
  });

  final int totalAmount;
  final List<CartItem> cartItems;
  final int? initialSubtotal;
  final int? initialDiscount;
  final int? initialShippingFee;
  final int? initialTotal;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  final _currency = NumberFormat('#,##0', 'vi_VN');
  final _paymentService = const PaymentOrderService();
  final _paymentInfoService = const PaymentInfoService();

  late final String _orderCode;
  PaymentMethod _selectedMethod = PaymentMethod.cod;
  Map<String, PaymentAccount> _paymentAccounts = const {};
  PaymentOrderResult? _createdOrder;
  PaymentTotals? _createdTotals;
  RealtimeChannel? _paymentChannel;
  Timer? _paymentPollTimer;
  bool _isSubmitting = false;
  bool _isLoadingPaymentInfo = true;
  bool _isCheckingPayment = false;
  bool _paymentCompleted = false;
  String? _paymentInfoError;

  @override
  void initState() {
    super.initState();
    _orderCode = PaymentOrderService.generateOrderCode();
    _loadPaymentInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _stopPaymentMonitoring();
    super.dispose();
  }

  String _money(int value) => '${_currency.format(value)}đ';

  List<CartItem> _checkoutItems(CartProvider cart) {
    return cart.items.isNotEmpty ? cart.items.toList() : widget.cartItems;
  }

  PaymentTotals _totalsFor(CartProvider cart, List<CartItem> items) {
    if (cart.items.isNotEmpty) return PaymentTotals.fromCart(cart);
    final subtotal =
        widget.initialSubtotal ??
        items.fold<int>(
          0,
          (sum, item) => sum + item.lineTotal(isAgent: cart.isAgent),
        );
    final shippingFee =
        widget.initialShippingFee ??
        (subtotal <= 0 || subtotal >= 500000 ? 0 : 30000);
    final discount = widget.initialDiscount ?? 0;
    final totalAmount = widget.initialTotal ?? widget.totalAmount;

    return PaymentTotals(
      subtotal: subtotal,
      shippingFee: shippingFee,
      discount: discount,
      totalAmount: totalAmount,
      couponApplied: discount > 0,
    );
  }

  Future<void> _loadPaymentInfo() async {
    if (mounted) {
      setState(() {
        _isLoadingPaymentInfo = true;
        _paymentInfoError = null;
      });
    }

    try {
      final accounts = await _paymentInfoService.fetchActiveAccounts();
      if (!mounted) return;
      setState(() {
        _paymentAccounts = accounts;
        if (_selectedMethod != PaymentMethod.cod &&
            !accounts.containsKey(_selectedMethod.id)) {
          _selectedMethod = PaymentMethod.cod;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _paymentAccounts = const {};
        _selectedMethod = PaymentMethod.cod;
        _paymentInfoError =
            'Không tải được thông tin chuyển khoản. Bạn vẫn có thể chọn COD.';
      });
    } finally {
      if (mounted) setState(() => _isLoadingPaymentInfo = false);
    }
  }

  Future<void> _submit(CartProvider cart) async {
    if (_createdOrder != null) {
      await _checkCreatedOrder(showLoading: true, showPendingMessage: true);
      return;
    }

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final items = _checkoutItems(cart);
    if (items.isEmpty) {
      _showSnack('Giỏ hàng đang trống', isError: true);
      return;
    }

    final totals = _totalsFor(cart, items);
    if (_selectedMethod != PaymentMethod.cod &&
        !_paymentAccounts.containsKey(_selectedMethod.id)) {
      _showSnack(
        'Phương thức này chưa có thông tin nhận tiền hợp lệ',
        isError: true,
      );
      return;
    }

    final confirmed = await _confirmPayment(totals.totalAmount);
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final snapshotItems = items.map((item) => item.copy()).toList();
      final order = await _paymentService.createOrder(
        items: snapshotItems,
        totals: totals,
        method: _selectedMethod,
        isAgent: cart.isAgent,
        orderCode: _orderCode,
        recipientName: _nameController.text,
        recipientPhone: _phoneController.text,
        shippingAddress: _addressController.text,
        note: _noteController.text,
      );

      if (!mounted) return;
      setState(() {
        _createdOrder = order;
        _createdTotals = totals;
      });

      if (_selectedMethod == PaymentMethod.cod) {
        await _completeOrder(cart: cart, isPaid: false);
        return;
      }

      _startPaymentMonitoring(order);
      _showSnack(
        'Đã tạo đơn #${order.code}. Hãy chuyển đúng số tiền và nội dung.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyCheckoutError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _confirmPayment(int totalAmount) {
    final isCod = _selectedMethod == PaymentMethod.cod;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isCod
                ? 'Xác nhận đặt hàng COD?'
                : 'Tạo đơn thanh toán ${_money(totalAmount)}?',
          ),
          content: Text(
            isCod
                ? 'Đơn hàng sẽ được tạo với số tiền ${_money(totalAmount)}.'
                : 'Sau khi tạo đơn, mã QR đúng số tiền và nội dung chuyển khoản sẽ được hiển thị.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Quay lại'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_rounded),
              label: Text(isCod ? 'Đặt hàng' : 'Tạo đơn'),
            ),
          ],
        );
      },
    );
  }

  void _startPaymentMonitoring(PaymentOrderResult order) {
    _stopPaymentMonitoring();
    _paymentChannel = SupabaseService.client
        .channel('checkout_payment_${order.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: order.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final status = payload.newRecord['payment_status']
                ?.toString()
                .toLowerCase();
            if (status == 'paid') {
              _completeOrder(cart: context.read<CartProvider>(), isPaid: true);
            }
          },
        )
        .subscribe();

    _paymentPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkCreatedOrder();
    });
  }

  void _stopPaymentMonitoring() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    final channel = _paymentChannel;
    _paymentChannel = null;
    if (channel != null && SupabaseService.isInitialized) {
      SupabaseService.client.removeChannel(channel);
    }
  }

  Future<void> _checkCreatedOrder({
    bool showLoading = false,
    bool showPendingMessage = false,
  }) async {
    final order = _createdOrder;
    if (order == null || _paymentCompleted || _isCheckingPayment) return;

    _isCheckingPayment = true;
    if (showLoading && mounted) setState(() {});
    try {
      final state = await _paymentService.fetchPaymentState(order.id);
      if (!mounted || _paymentCompleted) return;
      if (state.isPaid) {
        await _completeOrder(cart: context.read<CartProvider>(), isPaid: true);
      } else if (showPendingMessage) {
        _showSnack(
          'Chưa nhận được giao dịch. Hệ thống vẫn đang tự động kiểm tra.',
        );
      }
    } catch (error) {
      if (showPendingMessage && mounted) {
        _showSnack(
          'Chưa kiểm tra được thanh toán, vui lòng thử lại',
          isError: true,
        );
      }
    } finally {
      _isCheckingPayment = false;
      if (showLoading && mounted) setState(() {});
    }
  }

  Future<void> _completeOrder({
    required CartProvider cart,
    required bool isPaid,
  }) async {
    final order = _createdOrder;
    final totals = _createdTotals;
    if (_paymentCompleted || order == null || totals == null || !mounted) {
      return;
    }

    _paymentCompleted = true;
    _stopPaymentMonitoring();
    if (mounted) setState(() => _isSubmitting = true);
    await _clearCartSafely(cart);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId: order.id,
          orderCode: order.code,
          totalAmount: totals.totalAmount,
          subtotal: totals.subtotal,
          shippingFee: totals.shippingFee,
          discount: totals.discount,
          paymentMethodLabel: _selectedMethod.successLabel,
          isPaid: isPaid,
        ),
      ),
    );
  }

  Future<void> _clearCartSafely(CartProvider cart) async {
    try {
      await cart.clearCart();
    } catch (_) {
      cart.clear();
    }
  }

  String _friendlyCheckoutError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      return error.message.isEmpty
          ? 'Không tạo được đơn hàng, vui lòng kiểm tra mạng và thử lại'
          : error.message;
    }
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty
        ? 'Không tạo được đơn hàng, vui lòng kiểm tra mạng và thử lại'
        : text;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.blazeColor : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = _checkoutItems(cart);
    final totals = _createdTotals ?? _totalsFor(cart, items);
    final orderCreated = _createdOrder != null;

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: const Color(PaymentPalette.background),
        appBar: AppBar(
          title: Text(
            orderCreated ? 'Thanh toán #${_createdOrder!.code}' : 'Thanh toán',
          ),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _PaymentPanel(
                title: 'Thông tin giao hàng',
                icon: Icons.local_shipping_outlined,
                child: _ShippingForm(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  addressController: _addressController,
                  noteController: _noteController,
                  enabled: !orderCreated,
                ),
              ),
              const SizedBox(height: 12),
              _PaymentPanel(
                title: 'Sản phẩm đặt mua',
                icon: Icons.receipt_long_outlined,
                child: _OrderReviewList(
                  items: items,
                  money: _money,
                  isAgent: cart.isAgent,
                ),
              ),
              const SizedBox(height: 12),
              _PaymentPanel(
                title: 'Chọn thanh toán',
                icon: Icons.payments_outlined,
                child: PaymentMethodSelector(
                  selected: _selectedMethod,
                  totalAmount: totals.totalAmount,
                  orderCode: _createdOrder?.code ?? _orderCode,
                  money: _money,
                  accounts: _paymentAccounts,
                  isLoadingAccounts: _isLoadingPaymentInfo,
                  accountError: _paymentInfoError,
                  paymentReady: orderCreated,
                  enabled: !orderCreated,
                  onRetry: _loadPaymentInfo,
                  onChanged: (method) {
                    if (!orderCreated) {
                      setState(() => _selectedMethod = method);
                    }
                  },
                ),
              ),
              if (orderCreated && _selectedMethod != PaymentMethod.cod) ...[
                const SizedBox(height: 12),
                _PaymentWaitingPanel(
                  orderCode: _createdOrder!.code,
                  isChecking: _isCheckingPayment,
                  onCheck: () => _checkCreatedOrder(
                    showLoading: true,
                    showPendingMessage: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _CheckoutSummaryBar(
          totals: totals,
          money: _money,
          method: _selectedMethod,
          isSubmitting: _isSubmitting,
          isCheckingPayment: _isCheckingPayment,
          orderCreated: orderCreated,
          onSubmit: () => _submit(cart),
        ),
      ),
    );
  }
}

class _ShippingForm extends StatelessWidget {
  const _ShippingForm({
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.noteController,
    required this.enabled,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController noteController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Họ tên người nhận',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phoneController,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (value) {
            final phone = (value ?? '').trim();
            if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
            if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
              return 'Số điện thoại phải gồm 10 số và bắt đầu bằng 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: addressController,
          enabled: enabled,
          minLines: 2,
          maxLines: 3,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ giao hàng',
            prefixIcon: Icon(Icons.home_outlined),
          ),
          validator: (value) => (value ?? '').trim().isEmpty
              ? 'Vui lòng nhập địa chỉ giao hàng'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: noteController,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Ghi chú',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
      ],
    );
  }
}

class _OrderReviewList extends StatelessWidget {
  const _OrderReviewList({
    required this.items,
    required this.money,
    required this.isAgent,
  });

  final List<CartItem> items;
  final String Function(int value) money;
  final bool isAgent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'Giỏ hàng đang trống',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductThumb(url: item.product.imageUrls.firstOrNull ?? ''),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.weight} - ${item.grindType} - SL ${item.quantity}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.mutedColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money(item.lineTotal(isAgent: isAgent)),
                    style: const TextStyle(
                      color: Color(PaymentPalette.gold),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CheckoutSummaryBar extends StatelessWidget {
  const _CheckoutSummaryBar({
    required this.totals,
    required this.money,
    required this.method,
    required this.isSubmitting,
    required this.isCheckingPayment,
    required this.orderCreated,
    required this.onSubmit,
  });

  final PaymentTotals totals;
  final String Function(int value) money;
  final PaymentMethod method;
  final bool isSubmitting;
  final bool isCheckingPayment;
  final bool orderCreated;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isCod = method == PaymentMethod.cod;
    final isBusy = isSubmitting || isCheckingPayment;
    final buttonLabel = isCod
        ? 'ĐẶT HÀNG COD'
        : orderCreated
        ? 'KIỂM TRA THANH TOÁN'
        : 'TẠO ĐƠN & LẤY MÃ QR';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.lineColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: 'Tiền hàng', value: money(totals.subtotal)),
            _SummaryRow(label: 'Phí ship', value: money(totals.shippingFee)),
            _SummaryRow(
              label: 'Giảm giá',
              value: totals.discount > 0 ? '-${money(totals.discount)}' : '0đ',
            ),
            const Divider(height: 18),
            _SummaryRow(
              label: 'TỔNG CỘNG',
              value: money(totals.totalAmount),
              isTotal: true,
            ),
            const SizedBox(height: 12),
            if (orderCreated && !isCod) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Đang chờ ngân hàng xác nhận',
                    style: TextStyle(color: AppTheme.mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onSubmit,
                icon: isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Icon(
                        orderCreated
                            ? Icons.refresh_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentWaitingPanel extends StatelessWidget {
  const _PaymentWaitingPanel({
    required this.orderCode,
    required this.isChecking,
    required this.onCheck,
  });

  final String orderCode;
  final bool isChecking;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, color: AppTheme.goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đang chờ xác nhận thanh toán',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đơn #$orderCode sẽ tự cập nhật khi nhận được giao dịch.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kiểm tra ngay',
            onPressed: isChecking ? null : onCheck,
            icon: isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(PaymentPalette.gold)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? AppTheme.creamColor : AppTheme.mutedColor,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: isTotal ? 0.5 : 0,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal
                  ? const Color(PaymentPalette.gold)
                  : AppTheme.creamColor,
              fontSize: isTotal ? 22 : null,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const _ThumbPlaceholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _ThumbPlaceholder(),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.coffee_rounded, color: AppTheme.goldColor),
    );
  }
}
