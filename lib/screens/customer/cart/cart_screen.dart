import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../features/payment/payment_totals.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/login_gate.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.onExploreProducts});

  final VoidCallback? onExploreProducts;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  bool _isClearingCart = false;
  bool _isOpeningCheckout = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  String _money(int value) => '${_currency.format(value)}đ';

  Future<void> _applyCoupon() async {
    final cart = context.read<CartProvider>();
    final ok = await cart.applyDiscountCode(_couponController.text);
    if (!mounted) return;

    final message =
        cart.discountMessage ??
        (ok ? 'Đã áp dụng mã giảm giá' : 'Mã giảm giá không hợp lệ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppTheme.surfaceRaisedColor : AppTheme.blazeColor,
      ),
    );
  }

  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa toàn bộ giỏ hàng?'),
        content: const Text(
          'Tất cả sản phẩm đang chọn sẽ được xóa khỏi giỏ hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Xóa giỏ hàng'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearingCart = true);
    try {
      await context.read<CartProvider>().clearCart();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa toàn bộ giỏ hàng')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không xóa được giỏ hàng: $error'),
          backgroundColor: AppTheme.blazeColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isClearingCart = false);
    }
  }

  Future<void> _openCheckout() async {
    if (_isOpeningCheckout) return;
    if (!await requireLogin(context) || !mounted) return;

    setState(() => _isOpeningCheckout = true);
    try {
      final cart = context.read<CartProvider>();
      await cart.syncWithCurrentUser();
      if (!mounted) return;

      if (cart.items.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Giỏ hàng đang trống')));
        return;
      }

      final totals = PaymentTotals.fromCart(cart);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            cartItems: cart.items.toList(),
            totalAmount: totals.totalAmount,
            initialSubtotal: totals.subtotal,
            initialDiscount: totals.discount,
            initialShippingFee: totals.shippingFee,
            initialTotal: totals.totalAmount,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở thanh toán: $error'),
          backgroundColor: AppTheme.blazeColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final totals = PaymentTotals.fromCart(cart);
    final isBusy = cart.isBusy || _isClearingCart || _isOpeningCheckout;

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        centerTitle: false,
        actions: [
          if (cart.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  '${cart.totalItemCount} sản phẩm',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? _EmptyCart(
              isLoading: cart.isLoading,
              onExploreProducts: widget.onExploreProducts,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 920;
                if (isWide) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _CartContents(
                                cart: cart,
                                controller: _couponController,
                                money: _money,
                                isBusy: isBusy,
                                showSummary: false,
                                onApplyCoupon: _applyCoupon,
                                onClearCart: _confirmClearCart,
                                onCheckout: _openCheckout,
                              ),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 360,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(top: 44),
                                child: _OrderSummary(
                                  totals: totals,
                                  money: _money,
                                  isBusy: isBusy,
                                  showCheckoutButton: true,
                                  onCheckout: _openCheckout,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: _CartContents(
                        cart: cart,
                        controller: _couponController,
                        money: _money,
                        isBusy: isBusy,
                        showSummary: true,
                        onApplyCoupon: _applyCoupon,
                        onClearCart: _confirmClearCart,
                        onCheckout: _openCheckout,
                      ),
                    ),
                    _MobileCheckoutBar(
                      total: totals.totalAmount,
                      money: _money,
                      isBusy: isBusy,
                      onCheckout: _openCheckout,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _CartContents extends StatelessWidget {
  const _CartContents({
    required this.cart,
    required this.controller,
    required this.money,
    required this.isBusy,
    required this.showSummary,
    required this.onApplyCoupon,
    required this.onClearCart,
    required this.onCheckout,
  });

  final CartProvider cart;
  final TextEditingController controller;
  final String Function(int value) money;
  final bool isBusy;
  final bool showSummary;
  final Future<void> Function() onApplyCoupon;
  final VoidCallback onClearCart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final totals = PaymentTotals.fromCart(cart);

    return RefreshIndicator(
      onRefresh: () => context.read<CartProvider>().reloadFromSupabase(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          showSummary ? 16 : 0,
          8,
          showSummary ? 16 : 0,
          24,
        ),
        children: [
          _CartSectionHeader(
            distinctItems: cart.items.length,
            totalItems: cart.totalItemCount,
            isBusy: isBusy,
            onClearCart: onClearCart,
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < cart.items.length; index++) ...[
            _CartItemCard(item: cart.items[index], money: money),
            if (index != cart.items.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          _CouponBox(
            controller: controller,
            message: cart.discountMessage,
            hasCoupon: cart.discountCode != null,
            isLoading: cart.isApplyingCoupon,
            onApply: onApplyCoupon,
          ),
          if (showSummary) ...[
            const SizedBox(height: 16),
            _OrderSummary(
              totals: totals,
              money: money,
              isBusy: isBusy,
              showCheckoutButton: false,
              onCheckout: onCheckout,
            ),
          ],
        ],
      ),
    );
  }
}

class _CartSectionHeader extends StatelessWidget {
  const _CartSectionHeader({
    required this.distinctItems,
    required this.totalItems,
    required this.isBusy,
    required this.onClearCart,
  });

  final int distinctItems;
  final int totalItems;
  final bool isBusy;
  final VoidCallback onClearCart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sản phẩm đã chọn',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$distinctItems loại · $totalItems sản phẩm',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: isBusy ? null : onClearCart,
          icon: const Icon(Icons.delete_sweep_outlined, size: 19),
          label: const Text('Xóa tất cả'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item, required this.money});

  final CartItem item;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final isBusy = cart.isItemBusy(item);
    final unitPrice = item.unitPrice(isAgent: cart.isAgent);
    final lineTotal = item.lineTotal(isAgent: cart.isAgent);

    return Dismissible(
      key: ValueKey('${item.product.id}-${item.weight}-${item.grindType}'),
      direction: isBusy ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final message = await context.read<CartProvider>().removeFromCart(item);
        if (message != null && context.mounted) {
          _showActionMessage(context, message);
        }
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.lineColor),
        ),
        child: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: isBusy ? 0.48 : 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductThumb(
                      url: item.product.imageUrls.isEmpty
                          ? ''
                          : item.product.imageUrls.first,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Xóa sản phẩm',
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        final message = await context
                                            .read<CartProvider>()
                                            .removeFromCart(item);
                                        if (!context.mounted) return;
                                        _showActionMessage(context, message);
                                      },
                                icon: const Icon(Icons.close_rounded, size: 20),
                                constraints: const BoxConstraints.tightFor(
                                  width: 34,
                                  height: 34,
                                ),
                                padding: EdgeInsets.zero,
                                color: AppTheme.mutedColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _ProductOption(
                            icon: Icons.scale_outlined,
                            label: item.weight,
                          ),
                          const SizedBox(height: 3),
                          _ProductOption(
                            icon: Icons.local_cafe_outlined,
                            label: item.grindType,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${money(unitPrice)} / sản phẩm',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _QuantityControl(
                                quantity: item.quantity,
                                enabled: !isBusy,
                                onDecrease: () async {
                                  final message = await context
                                      .read<CartProvider>()
                                      .decrement(item);
                                  if (!context.mounted) return;
                                  _showActionMessage(context, message);
                                },
                                onIncrease: () async {
                                  final message = await context
                                      .read<CartProvider>()
                                      .increment(item);
                                  if (!context.mounted) return;
                                  _showActionMessage(context, message);
                                },
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    money(lineTotal),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppTheme.goldColor,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isBusy)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _showActionMessage(BuildContext context, String? message) {
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.blazeColor),
    );
  }
}

class _ProductOption extends StatelessWidget {
  const _ProductOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.mutedColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const _PlaceholderThumb();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 88,
        height: 112,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: 88,
          height: 112,
          color: AppTheme.surfaceAltColor,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, _, _) => const _PlaceholderThumb(),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 112,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.coffee_rounded,
        size: 32,
        color: AppTheme.goldColor,
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.enabled,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool enabled;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove_rounded,
            tooltip: 'Giảm số lượng',
            onPressed: enabled ? onDecrease : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _QuantityButton(
            icon: Icons.add_rounded,
            tooltip: 'Tăng số lượng',
            onPressed: enabled ? onIncrease : null,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      color: AppTheme.creamColor,
    );
  }
}

class _CouponBox extends StatelessWidget {
  const _CouponBox({
    required this.controller,
    required this.message,
    required this.hasCoupon,
    required this.isLoading,
    required this.onApply,
  });

  final TextEditingController controller;
  final String? message;
  final bool hasCoupon;
  final bool isLoading;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCoupon
                    ? Icons.check_circle_outline_rounded
                    : Icons.local_offer_outlined,
                size: 20,
                color: hasCoupon ? AppTheme.successColor : AppTheme.goldColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Mã giảm giá',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Nhập mã ưu đãi',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                    isDense: true,
                  ),
                  onSubmitted: (_) async {
                    if (!isLoading) await onApply();
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onApply,
                  icon: isLoading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 9),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasCoupon
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.totals,
    required this.money,
    required this.isBusy,
    required this.showCheckoutButton,
    required this.onCheckout,
  });

  final PaymentTotals totals;
  final String Function(int value) money;
  final bool isBusy;
  final bool showCheckoutButton;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tóm tắt đơn hàng',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Tiền hàng', value: money(totals.subtotal)),
          _SummaryRow(label: 'Phí giao hàng', value: money(totals.shippingFee)),
          _SummaryRow(
            label: 'Giảm giá',
            value: totals.discount > 0 ? '-${money(totals.discount)}' : '0đ',
            valueColor: totals.discount > 0 ? AppTheme.successColor : null,
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'TỔNG CỘNG',
            value: money(totals.totalAmount),
            isTotal: true,
          ),
          if (showCheckoutButton) ...[
            const SizedBox(height: 18),
            _CheckoutButton(
              isBusy: isBusy,
              onPressed: onCheckout,
              label: 'ĐẶT HÀNG NGAY',
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isTotal ? AppTheme.creamColor : AppTheme.mutedColor,
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      valueColor ??
                      (isTotal ? AppTheme.goldColor : AppTheme.creamColor),
                  fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isTotal ? 22 : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCheckoutBar extends StatelessWidget {
  const _MobileCheckoutBar({
    required this.total,
    required this.money,
    required this.isBusy,
    required this.onCheckout,
  });

  final int total;
  final String Function(int value) money;
  final bool isBusy;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.lineColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tổng cộng',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      money(total),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.goldColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: _CheckoutButton(
                isBusy: isBusy,
                onPressed: onCheckout,
                label: 'ĐẶT HÀNG',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    required this.isBusy,
    required this.onPressed,
    required this.label,
  });

  final bool isBusy;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_rounded),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.isLoading, required this.onExploreProducts});

  final bool isLoading;
  final VoidCallback? onExploreProducts;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lineColor),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(
                        Icons.shopping_bag_outlined,
                        size: 42,
                        color: AppTheme.goldColor,
                      ),
              ),
              const SizedBox(height: 20),
              Text(
                isLoading
                    ? 'Đang tải giỏ hàng...'
                    : 'Giỏ hàng của bạn đang trống',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (!isLoading) ...[
                const SizedBox(height: 8),
                Text(
                  'Chọn cà phê yêu thích để bắt đầu đơn hàng.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onExploreProducts,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Khám phá sản phẩm'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
