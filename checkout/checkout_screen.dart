import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/address_item_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/login_gate.dart';
import '../shipping_address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.cartItems = const [],
    this.initialSubtotal,
    this.initialDiscount,
    this.initialShippingFee,
    this.initialTotal,
  });

  final List<CartItem> cartItems;
  final int? initialSubtotal;
  final int? initialDiscount;
  final int? initialShippingFee;
  final int? initialTotal;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSubmitting = false;
  late Future<List<AddressItem>> _addressesFuture;
  String? _selectedAddressId;
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _addressesFuture = _loadAddresses();
  }

  Future<List<AddressItem>> _loadAddresses() async {
    final addresses = await SupabaseService.fetchAddresses();
    if (_selectedAddressId == null && addresses.isNotEmpty) {
      _selectedAddressId = addresses.firstWhere(
        (item) => item.isDefault,
        orElse: () => addresses.first,
      ).id;
    } else if (_selectedAddressId != null &&
        !addresses.any((item) => item.id == _selectedAddressId)) {
      _selectedAddressId = addresses.isEmpty ? null : addresses.first.id;
    }
    return addresses;
  }

  Future<void> _refreshAddresses() async {
    setState(() {
      _addressesFuture = _loadAddresses();
    });
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final checkoutItems = cart.items.isNotEmpty ? cart.items : widget.cartItems;
    if (checkoutItems.isEmpty) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    if (_selectedAddressId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa chỉ giao hàng')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final orderId = await SupabaseService.createOrderWithPricing(
        items: checkoutItems,
        subtotal: cart.items.isNotEmpty ? cart.subtotal : (widget.initialSubtotal ?? 0),
        discountAmount: cart.items.isNotEmpty
            ? cart.discountAmount
            : (widget.initialDiscount ?? 0),
        shippingFee: cart.items.isNotEmpty
            ? cart.shippingFee
            : (widget.initialShippingFee ?? 0),
        total: cart.items.isNotEmpty ? cart.total : (widget.initialTotal ?? 0),
        isAgent: cart.isAgent,
      );
      try {
        await cart.markCouponUsed();
      } catch (error, stackTrace) {
        debugPrint('Không tăng được lượt dùng coupon: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      await cart.clearCart();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId)),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.blazeColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openAddressManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShippingAddressScreen()),
    );
    if (!mounted) return;
    await _refreshAddresses();
  }

  String _money(int value) => '${_currency.format(value)}đ';

  Widget _buildAddressSection(List<AddressItem> addresses) {
    final selected = addresses.cast<AddressItem?>().firstWhere(
          (item) => item?.id == _selectedAddressId,
          orElse: () => addresses.isNotEmpty ? addresses.first : null,
        );

    if (addresses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Địa chỉ giao hàng',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Bạn chưa có địa chỉ nào được lưu.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openAddressManager,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Thêm địa chỉ'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Địa chỉ giao hàng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: _openAddressManager,
                  child: const Text('Quản lý'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...addresses.map((address) {
              final isSelected = _selectedAddressId == address.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedAddressId = address.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? AppTheme.goldColor : AppTheme.mutedColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      address.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (address.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.flameGradient,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Mặc định',
                                        style: TextStyle(
                                          color: AppTheme.charColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${address.phone}\n${address.formattedAddress}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.mutedColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (selected != null) ...[
              const SizedBox(height: 8),
              Text(
                'Sẽ giao tới: ${selected.formattedAddress}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final displayTotal = cart.items.isNotEmpty ? cart.total : (widget.initialTotal ?? 0);

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(title: const Text('Thanh Toán'), centerTitle: true),
      body: FutureBuilder<List<AddressItem>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          final addresses = snapshot.data ?? const <AddressItem>[];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng thanh toán',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(displayTotal),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.goldColor,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Đơn hàng sẽ được gửi đến Hải Tín để duyệt và đóng gói.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildAddressSection(addresses),
              const SizedBox(height: 18),
              SizedBox(
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
                    onPressed: _isSubmitting ? null : _placeOrder,
                    child: Text(
                      _isSubmitting ? 'Đang đặt hàng...' : 'Đặt hàng',
                      style: const TextStyle(
                        color: AppTheme.charColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        title: const Text('Đặt Hàng Thành Công'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  gradient: AppTheme.flameGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.charColor,
                  size: 52,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Đặt hàng thành công',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã đơn: $orderId',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.goldColor),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
