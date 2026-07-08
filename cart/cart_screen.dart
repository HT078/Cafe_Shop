import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  String _money(int value) => '${_currency.format(value)}đ';

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(title: const Text('Giỏ Hàng'), centerTitle: true),
      body: cart.items.isEmpty
          ? _EmptyCart(
              isLoading: cart.isLoading,
              onExploreProducts: widget.onExploreProducts,
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => context.read<CartProvider>().reloadFromSupabase(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      itemCount: cart.items.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == cart.items.length) {
                          return _CouponBox(
                            controller: _couponController,
                            message: cart.discountMessage,
                            isLoading: cart.isApplyingCoupon,
                            onApply: () async {
                              final ok = await context
                                  .read<CartProvider>()
                                  .applyDiscountCode(_couponController.text);
                              if (!context.mounted) return;
                              final message = context.read<CartProvider>().discountMessage ??
                                  (ok
                                      ? 'Đã áp dụng mã giảm giá'
                                      : 'Mã giảm giá không hợp lệ');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: ok ? null : AppTheme.blazeColor,
                                ),
                              );
                            },
                          );
                        }

                        return _CartItemCard(
                          item: cart.items[index],
                          money: _money,
                        );
                      },
                    ),
                  ),
                ),
                _CartSummary(
                  subtotal: cart.subtotal,
                  discount: cart.discountAmount,
                  shippingFee: cart.shippingFee,
                  total: cart.total,
                  isBusy: cart.isBusy,
                  money: _money,
                ),
              ],
            ),
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

    return Dismissible(
      key: ValueKey('${item.product.id}-${item.weight}-${item.grindType}'),
      direction: isBusy ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.blazeColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final message = await context.read<CartProvider>().removeFromCart(item);
        if (message != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.blazeColor),
          );
        }
        return false;
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Opacity(
                opacity: isBusy ? 0.55 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductThumb(url: item.product.imageUrls.isEmpty ? '' : item.product.imageUrls.first),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gói ${item.weight} · ${item.grindType}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.mutedColor,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _QtyButton(
                                icon: Icons.remove_rounded,
                                onTap: isBusy
                                    ? null
                                    : () async {
                                        final message = await context
                                            .read<CartProvider>()
                                            .decrement(item);
                                        if (!context.mounted) return;
                                        _showActionMessage(context, message);
                                      },
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              _QtyButton(
                                icon: Icons.add_rounded,
                                onTap: isBusy
                                    ? null
                                    : () async {
                                        final message = await context
                                            .read<CartProvider>()
                                            .increment(item);
                                        if (!context.mounted) return;
                                        _showActionMessage(context, message);
                                      },
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        final message = await context
                                            .read<CartProvider>()
                                            .removeFromCart(item);
                                        if (!context.mounted) return;
                                        _showActionMessage(context, message);
                                      },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppTheme.mutedColor,
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              money(item.lineTotal(isAgent: cart.isAgent)),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.goldColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      ),
    );
  }

  void _showActionMessage(BuildContext context, String? message) {
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.blazeColor),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _PlaceholderThumb();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _PlaceholderThumb(),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(gradient: AppTheme.flameGradient),
      child: const Icon(Icons.coffee_rounded, color: AppTheme.charColor),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.lineColor),
        ),
        child: Icon(icon, size: 18, color: onTap == null ? AppTheme.mutedColor : null),
      ),
    );
  }
}

class _CouponBox extends StatelessWidget {
  const _CouponBox({
    required this.controller,
    required this.message,
    required this.isLoading,
    required this.onApply,
  });

  final TextEditingController controller;
  final String? message;
  final bool isLoading;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã giảm giá / chiết khấu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Nhập mã giảm giá'),
                    onSubmitted: (_) => isLoading ? null : onApply(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.flameGradient,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: TextButton(
                    onPressed: isLoading ? null : onApply,
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Áp dụng',
                            style: TextStyle(
                              color: AppTheme.charColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.goldColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.total,
    required this.isBusy,
    required this.money,
  });

  final int subtotal;
  final int discount;
  final int shippingFee;
  final int total;
  final bool isBusy;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.lineColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: 'Tạm tính', value: money(subtotal)),
            _SummaryRow(
              label: 'Giảm giá',
              value: discount > 0 ? '-${money(discount)}' : '0đ',
            ),
            _SummaryRow(
              label: 'Phí vận chuyển tạm tính',
              value: shippingFee == 0 ? 'Miễn phí' : money(shippingFee),
            ),
            const Divider(height: 22),
            _SummaryRow(label: 'Tổng cộng', value: money(total), isTotal: true),
            const SizedBox(height: 14),
            Opacity(
              opacity: isBusy ? 0.55 : 1,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.flameGradient,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: isBusy
                        ? null
                        : () async {
                            if (!await requireLogin(context)) return;
                            if (!context.mounted) return;
                            final cart = context.read<CartProvider>();
                            await cart.syncWithCurrentUser();
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CheckoutScreen(
                                  cartItems: cart.items,
                                  initialSubtotal: cart.subtotal,
                                  initialDiscount: cart.discountAmount,
                                  initialShippingFee: cart.shippingFee,
                                  initialTotal: cart.total,
                                ),
                              ),
                            );
                          },
                    child: const Text(
                      'Tiến hành thanh toán',
                      style: TextStyle(
                        color: AppTheme.charColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isTotal ? AppTheme.creamColor : AppTheme.mutedColor,
                    fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isTotal ? AppTheme.goldColor : AppTheme.creamColor,
                  fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isTotal ? 20 : null,
                ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.lineColor),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                      size: 44,
                      color: AppTheme.goldColor,
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              isLoading ? 'Đang tải giỏ hàng...' : 'Giỏ hàng của bạn đang trống',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.flameGradient,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: TextButton(
                onPressed: onExploreProducts,
                child: const Text(
                  'Khám phá sản phẩm',
                  style: TextStyle(
                    color: AppTheme.charColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
