import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/address_item_model.dart';
import '../../../providers/account_provider.dart';
import '../../../services/vietnam_admin_data.dart';
import '../../../theme/theme.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({super.key});

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AccountProvider>().load(force: true);
    });
  }

  Future<void> _openForm(BuildContext context, {AddressItem? address}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddressFormSheet(address: address),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AddressItem address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa địa chỉ'),
        content: const Text('Bạn có chắc muốn xóa địa chỉ này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AccountProvider>().deleteAddress(address.id);
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa địa chỉ')));
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể xóa địa chỉ: $error')),
      );
    }
  }

  Future<void> _setDefaultAddress(
    BuildContext context,
    AddressItem address,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AccountProvider>().setDefaultAddress(address.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã đặt làm mặc định')),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể cập nhật địa chỉ: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = context.watch<AccountProvider>().addresses;

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      appBar: AppBar(title: const Text('Địa chỉ giao hàng'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm địa chỉ mới'),
        backgroundColor: AppTheme.goldColor,
      ),
      body: addresses.isEmpty
          ? _EmptyAddressState(onAdd: () => _openForm(context))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: addresses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressCard(
                  address: address,
                  onEdit: () => _openForm(context, address: address),
                  onDelete: () => _confirmDelete(context, address),
                  onSetDefault: () => _setDefaultAddress(context, address),
                );
              },
            ),
    );
  }
}

class _EmptyAddressState extends StatelessWidget {
  const _EmptyAddressState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 46,
              color: AppTheme.mutedColor,
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn chưa có địa chỉ nào',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm địa chỉ để đặt hàng nhanh hơn.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Thêm địa chỉ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final AddressItem address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

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
                Expanded(
                  child: Text(
                    address.fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
            const SizedBox(height: 8),
            Text(
              address.phone,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppTheme.goldColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.formattedAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Xóa'),
                ),
                if (!address.isDefault)
                  TextButton.icon(
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Đặt mặc định'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({this.address});

  final AddressItem? address;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _detailController;
  String? _province;
  String? _district;
  String? _ward;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _nameController = TextEditingController(text: address?.fullName ?? '');
    _phoneController = TextEditingController(text: address?.phone ?? '');
    _detailController = TextEditingController(
      text: address?.detailAddress ?? '',
    );
    _province = address?.province.isNotEmpty == true ? address!.province : null;
    _district = address?.district.isNotEmpty == true ? address!.district : null;
    _ward = address?.ward.isNotEmpty == true ? address!.ward : null;
    _isDefault = address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  List<String> get _districts {
    return _province == null
        ? const []
        : VietnamAdministrativeData.districtsOf(_province!);
  }

  List<String> get _wards {
    return _province == null || _district == null
        ? const []
        : VietnamAdministrativeData.wardsOf(_province!, _district!);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập thông tin';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Số điện thoại phải gồm đúng 10 số';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.address;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    try {
      await context.read<AccountProvider>().saveAddress(
        AddressItem(
          id: existing?.id ?? '',
          userId: existing?.userId ?? '',
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          province: _province!,
          district: _district!,
          ward: _ward!,
          detailAddress: _detailController.text.trim(),
          isDefault: _isDefault,
          createdAt: existing?.createdAt ?? DateTime.now(),
        ),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Đã thêm địa chỉ' : 'Đã lưu địa chỉ'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể lưu địa chỉ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.lineColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.address == null
                      ? 'Thêm địa chỉ mới'
                      : 'Chỉnh sửa địa chỉ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thiết lập địa chỉ nhận hàng để chọn nhanh ở bước thanh toán.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'Tên người nhận',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: _phoneValidator,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _province,
                  validator: (value) =>
                      value == null ? 'Chọn tỉnh/thành' : null,
                  decoration: const InputDecoration(labelText: 'Tỉnh / Thành'),
                  items: VietnamAdministrativeData.provinces
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _province = value;
                      _district = null;
                      _ward = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _district,
                  validator: (value) =>
                      value == null ? 'Chọn quận/huyện' : null,
                  decoration: const InputDecoration(labelText: 'Quận / Huyện'),
                  items: _districts
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _province == null
                      ? null
                      : (value) {
                          setState(() {
                            _district = value;
                            _ward = null;
                          });
                        },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _ward,
                  validator: (value) => value == null ? 'Chọn phường/xã' : null,
                  decoration: const InputDecoration(labelText: 'Phường / Xã'),
                  items: _wards
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _district == null
                      ? null
                      : (value) => setState(() => _ward = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _detailController,
                  maxLines: 2,
                  validator: _required,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ chi tiết',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _isDefault,
                  onChanged: (value) =>
                      setState(() => _isDefault = value ?? false),
                  title: const Text('Đặt làm địa chỉ mặc định'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
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
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Đang lưu...' : 'Lưu địa chỉ',
                        style: const TextStyle(
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
        ),
      ),
    );
  }
}
