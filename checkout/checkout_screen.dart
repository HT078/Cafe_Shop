import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/order_repository.dart';
import '../../../models/address_item_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/vietnam_admin_data.dart';
import '../../../theme/theme.dart';
import '../../../widgets/customer/login_gate.dart';
import 'order_success_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _noteController = TextEditingController();
  final _voucherController = TextEditingController();
  final _currency = NumberFormat('#,##0', 'vi_VN');

  late Future<List<AddressItem>> _addressesFuture;
  String _shippingMethod = 'standard';
  String _paymentMethod = 'cod';
  String? _province;
  String? _district;
  String? _ward;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _province = VietnamAdministrativeData.provinces.firstOrNull;
    _district = _province == null
        ? null
        : VietnamAdministrativeData.districtsOf(_province!).firstOrNull;
    _ward = _province == null || _district == null
        ? null
        : VietnamAdministrativeData.wardsOf(_province!, _district!).firstOrNull;
    _addressesFuture = _loadAddresses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailAddressController.dispose();
    _noteController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<List<AddressItem>> _loadAddresses() async {
    final account = context.read<AccountProvider>();
    await account.load();
    return account.addresses;
  }

  List<CartItem> _checkoutItems(CartProvider cart) {
    return cart.items.isNotEmpty ? cart.items : widget.cartItems;
  }

  int _subtotal(CartProvider cart, List<CartItem> items) {
    if (cart.items.isNotEmpty) return cart.subtotal;
    return widget.initialSubtotal ??
        items.fold(
          0,
          (sum, item) => sum + item.lineTotal(isAgent: cart.isAgent),
        );
  }

  int _discount(CartProvider cart) {
    if (cart.items.isNotEmpty) return cart.discountAmount;
    return widget.initialDiscount ?? 0;
  }

  int get _shippingFee => _shippingMethod == 'fast' ? 30000 : 20000;

  String get _shippingLabel =>
      _shippingMethod == 'fast' ? 'Giao nhanh' : 'Giao tiết kiệm';

  String _money(int value) => '${_currency.format(value)}đ';

  String _fullAddress() {
    return [
      _detailAddressController.text.trim(),
      _ward,
      _district,
      _province,
    ].where((part) => (part ?? '').trim().isNotEmpty).join(', ');
  }

  void _setProvince(String? value) {
    if (value == null) return;
    final districts = VietnamAdministrativeData.districtsOf(value);
    setState(() {
      _province = value;
      _district = districts.firstOrNull;
      _ward = _district == null
          ? null
          : VietnamAdministrativeData.wardsOf(value, _district!).firstOrNull;
    });
  }

  void _setDistrict(String? value) {
    if (value == null || _province == null) return;
    setState(() {
      _district = value;
      _ward = VietnamAdministrativeData.wardsOf(_province!, value).firstOrNull;
    });
  }

  void _useAddress(AddressItem address) {
    final province =
        VietnamAdministrativeData.provinces.contains(address.province)
        ? address.province
        : VietnamAdministrativeData.provinces.firstOrNull;
    final districts = province == null
        ? const <String>[]
        : VietnamAdministrativeData.districtsOf(province);
    final district = districts.contains(address.district)
        ? address.district
        : districts.firstOrNull;
    final wards = province == null || district == null
        ? const <String>[]
        : VietnamAdministrativeData.wardsOf(province, district);

    setState(() {
      _nameController.text = address.fullName;
      _phoneController.text = address.phone;
      _detailAddressController.text = address.detailAddress;
      _province = province;
      _district = district;
      _ward = wards.contains(address.ward) ? address.ward : wards.firstOrNull;
    });
  }

  Future<void> _showSavedAddresses(List<AddressItem> addresses) async {
    if (addresses.isEmpty) {
      _showSnack('Bạn chưa có địa chỉ đã lưu', isError: true);
      return;
    }

    final selected = await showModalBottomSheet<AddressItem>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.goldColor,
                ),
                title: Text(address.fullName),
                subtitle: Text('${address.phone}\n${address.formattedAddress}'),
                isThreeLine: true,
                trailing: address.isDefault
                    ? const Icon(Icons.star_rounded, color: AppTheme.goldColor)
                    : null,
                onTap: () => Navigator.of(context).pop(address),
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: addresses.length,
          ),
        );
      },
    );
    if (selected != null) _useAddress(selected);
  }

  Future<void> _applyVoucher(CartProvider cart) async {
    final ok = await cart.applyDiscountCode(_voucherController.text);
    if (!mounted) return;
    _showSnack(
      cart.discountMessage ??
          (ok ? 'Đã áp dụng mã giảm giá' : 'Mã giảm giá không hợp lệ'),
      isError: !ok,
    );
  }

  Future<void> _placeOrder(CartProvider cart) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!await requireLogin(context)) return;
    if (!mounted) return;

    final items = _checkoutItems(cart);
    if (items.isEmpty) {
      _showSnack('Giỏ hàng đang trống', isError: true);
      return;
    }

    final subtotal = _subtotal(cart, items);
    final discount = _discount(cart);
    final total = (subtotal - discount + _shippingFee)
        .clamp(0, 1 << 31)
        .toInt();

    setState(() => _isSubmitting = true);
    try {
      final order = await const OrderRepository().placeOrder(
        cartItems: items,
        recipientName: _nameController.text.trim(),
        recipientPhone: _phoneController.text.trim(),
        shippingAddress: _fullAddress(),
        shippingMethod: _shippingMethod,
        shippingFee: _shippingFee,
        paymentMethod: _paymentMethod,
        subtotal: subtotal,
        discountAmount: discount,
        total: total,
        isAgent: cart.isAgent,
        voucherCode: cart.discountCode,
        note: _noteController.text,
      );

      try {
        await cart.markCouponUsed();
      } catch (_) {
        // Đơn đã tạo thành công, không chặn flow chỉ vì tăng lượt coupon lỗi.
      }
      await cart.clearCart();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: order.id,
            orderCode: order.code,
            shippingMethodLabel: _shippingLabel,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyCheckoutError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyCheckoutError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      return error.message.isEmpty
          ? 'Không tạo được đơn hàng, vui lòng thử lại'
          : error.message;
    }
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Không tạo được đơn hàng, vui lòng thử lại' : text;
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
    final subtotal = _subtotal(cart, items);
    final discount = _discount(cart);
    final total = (subtotal - discount + _shippingFee)
        .clamp(0, 1 << 31)
        .toInt();

    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(title: const Text('Thanh toán'), centerTitle: true),
      body: FutureBuilder<List<AddressItem>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          final addresses = snapshot.data ?? const <AddressItem>[];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _SectionCard(
                  title: 'Thông tin giao hàng',
                  icon: Icons.local_shipping_outlined,
                  child: _ShippingInfoSection(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    detailAddressController: _detailAddressController,
                    noteController: _noteController,
                    province: _province,
                    district: _district,
                    ward: _ward,
                    onProvinceChanged: _setProvince,
                    onDistrictChanged: _setDistrict,
                    onWardChanged: (value) => setState(() => _ward = value),
                    onUseSavedAddress: () => _showSavedAddresses(addresses),
                    savedAddressCount: addresses.length,
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Xem lại đơn hàng',
                  icon: Icons.receipt_long_outlined,
                  child: _OrderReviewList(
                    items: items,
                    money: _money,
                    isAgent: cart.isAgent,
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Phương thức vận chuyển',
                  icon: Icons.delivery_dining_outlined,
                  child: RadioGroup<String>(
                    groupValue: _shippingMethod,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _shippingMethod = value);
                      }
                    },
                    child: Column(
                      children: [
                        _ChoiceTile(
                          value: 'fast',
                          groupValue: _shippingMethod,
                          title: 'Giao nhanh',
                          subtitle: '30.000đ - dự kiến 1-2 ngày',
                        ),
                        _ChoiceTile(
                          value: 'standard',
                          groupValue: _shippingMethod,
                          title: 'Giao tiết kiệm',
                          subtitle: '20.000đ - dự kiến 3-5 ngày',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Mã giảm giá',
                  icon: Icons.confirmation_number_outlined,
                  child: _VoucherSection(
                    controller: _voucherController,
                    discountAmount: discount,
                    message: cart.discountMessage,
                    isLoading: cart.isApplyingCoupon,
                    money: _money,
                    onApply: () => _applyVoucher(cart),
                    onRemove: cart.removeDiscountCode,
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Phương thức thanh toán',
                  icon: Icons.payments_outlined,
                  child: RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _paymentMethod = value);
                      }
                    },
                    child: Column(
                      children: [
                        _ChoiceTile(
                          value: 'cod',
                          groupValue: _paymentMethod,
                          title: 'COD',
                          subtitle: 'Thanh toán khi nhận hàng',
                        ),
                        _ChoiceTile(
                          value: 'vietqr',
                          groupValue: _paymentMethod,
                          title: 'VietQR',
                          subtitle: 'Chuyển khoản ngân hàng',
                        ),
                        _ChoiceTile(
                          value: 'momo',
                          groupValue: _paymentMethod,
                          title: 'Momo',
                          subtitle: 'Chuyển vào ví Momo cửa hàng',
                        ),
                        _ChoiceTile(
                          value: 'zalopay',
                          groupValue: _paymentMethod,
                          title: 'ZaloPay',
                          subtitle: 'Chuyển vào ví ZaloPay cửa hàng',
                        ),
                        _PaymentDetail(
                          method: _paymentMethod,
                          amount: total,
                          money: _money,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _CheckoutSummaryBar(
        subtotal: subtotal,
        shippingFee: _shippingFee,
        discount: discount,
        total: total,
        money: _money,
        isSubmitting: _isSubmitting,
        onSubmit: () => _placeOrder(cart),
      ),
    );
  }
}

class _ShippingInfoSection extends StatelessWidget {
  const _ShippingInfoSection({
    required this.nameController,
    required this.phoneController,
    required this.detailAddressController,
    required this.noteController,
    required this.province,
    required this.district,
    required this.ward,
    required this.onProvinceChanged,
    required this.onDistrictChanged,
    required this.onWardChanged,
    required this.onUseSavedAddress,
    required this.savedAddressCount,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController detailAddressController;
  final TextEditingController noteController;
  final String? province;
  final String? district;
  final String? ward;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onWardChanged;
  final VoidCallback onUseSavedAddress;
  final int savedAddressCount;

  @override
  Widget build(BuildContext context) {
    final districts = province == null
        ? const <String>[]
        : VietnamAdministrativeData.districtsOf(province!);
    final wards = province == null || district == null
        ? const <String>[]
        : VietnamAdministrativeData.wardsOf(province!, district!);

    return Column(
      children: [
        TextFormField(
          controller: nameController,
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
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: savedAddressCount == 0 ? null : onUseSavedAddress,
            icon: const Icon(Icons.bookmark_added_outlined),
            label: Text(
              savedAddressCount == 0
                  ? 'Chưa có địa chỉ đã lưu'
                  : 'Dùng địa chỉ đã lưu',
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: detailAddressController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ chi tiết',
            hintText: 'Số nhà, tên đường',
            prefixIcon: Icon(Icons.home_outlined),
          ),
          validator: (value) => (value ?? '').trim().isEmpty
              ? 'Vui lòng nhập địa chỉ chi tiết'
              : null,
        ),
        const SizedBox(height: 12),
        _DropdownField(
          label: 'Tỉnh/Thành',
          value: province,
          items: VietnamAdministrativeData.provinces,
          onChanged: onProvinceChanged,
        ),
        const SizedBox(height: 12),
        _DropdownField(
          label: 'Quận/Huyện',
          value: district,
          items: districts,
          onChanged: onDistrictChanged,
        ),
        const SizedBox(height: 12),
        _DropdownField(
          label: 'Phường/Xã',
          value: ward,
          items: wards,
          onChanged: onWardChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: noteController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Ghi chú cho shipper',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
      validator: (value) =>
          value == null || value.isEmpty ? 'Vui lòng chọn $label' : null,
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
                          '${item.weight} · ${item.grindType} · SL ${item.quantity}',
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
                      color: AppTheme.goldColor,
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

class _VoucherSection extends StatelessWidget {
  const _VoucherSection({
    required this.controller,
    required this.discountAmount,
    required this.message,
    required this.isLoading,
    required this.money,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int discountAmount;
  final String? message;
  final bool isLoading;
  final String Function(int value) money;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final applied = discountAmount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Nhập mã giảm giá'),
                onFieldSubmitted: (_) => isLoading ? null : onApply(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isLoading ? null : onApply,
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Áp dụng'),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  applied ? 'Giảm ${money(discountAmount)}' : message!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: applied ? Colors.greenAccent : AppTheme.blazeColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (applied)
                IconButton(
                  tooltip: 'Bỏ mã',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PaymentDetail extends StatelessWidget {
  const _PaymentDetail({
    required this.method,
    required this.amount,
    required this.money,
  });

  final String method;
  final int amount;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    if (method == 'cod') {
      return const SizedBox.shrink();
    }

    final title = switch (method) {
      'vietqr' => 'VietQR - Ngân hàng ACB',
      'momo' => 'Momo Hải Tín',
      'zalopay' => 'ZaloPay Hải Tín',
      _ => 'Thanh toán',
    };
    final account = switch (method) {
      'vietqr' => 'STK: 123456789 - CA PHE HAI TIN',
      'momo' => 'SĐT: 0909 000 000',
      'zalopay' => 'SĐT: 0909 000 000',
      _ => '',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: Row(
        children: [
          if (method == 'vietqr')
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.creamColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: AppTheme.charColor,
              ),
            ),
          if (method == 'vietqr') const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(account),
                const SizedBox(height: 4),
                Text(
                  'Số tiền: ${money(amount)}',
                  style: const TextStyle(
                    color: AppTheme.goldColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final String groupValue;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return RadioListTile<String>(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: AppTheme.goldColor,
      selected: selected,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      secondary: selected
          ? const Icon(Icons.check_circle_rounded, color: AppTheme.goldColor)
          : null,
    );
  }
}

class _CheckoutSummaryBar extends StatelessWidget {
  const _CheckoutSummaryBar({
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.total,
    required this.money,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int subtotal;
  final int shippingFee;
  final int discount;
  final int total;
  final String Function(int value) money;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
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
            _SummaryRow(label: 'Tạm tính', value: money(subtotal)),
            _SummaryRow(label: 'Phí vận chuyển', value: money(shippingFee)),
            _SummaryRow(
              label: 'Giảm giá',
              value: discount > 0 ? '-${money(discount)}' : '0đ',
            ),
            const Divider(height: 18),
            _SummaryRow(label: 'Tổng cộng', value: money(total), isTotal: true),
            const SizedBox(height: 12),
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
                  onPressed: isSubmitting ? null : onSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text(
                          'XÁC NHẬN ĐẶT HÀNG',
                          style: TextStyle(
                            color: AppTheme.charColor,
                            fontWeight: FontWeight.w900,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
                Icon(icon, color: AppTheme.goldColor),
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
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? AppTheme.goldColor : AppTheme.creamColor,
              fontSize: isTotal ? 20 : null,
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
