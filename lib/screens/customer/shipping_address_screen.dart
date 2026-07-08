import 'package:flutter/material.dart';

import '../../models/address_item_model.dart';
import '../../services/supabase_service.dart';
import '../../services/vietnam_admin_data.dart';
import '../../theme/theme.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({super.key});

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  late Future<List<AddressItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AddressItem>> _load() async {
    return SupabaseService.fetchAddresses();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm({AddressItem? address}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddressFormSheet(
        address: address,
        onSaved: _refresh,
      ),
    );
  }

  Future<void> _confirmDelete(AddressItem address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa địa chỉ'),
        content: const Text('Bạn chắc chắn muốn xóa địa chỉ này?'),
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

    if (confirm != true) return;
    await SupabaseService.deleteAddress(address.id);
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        title: const Text('Địa chỉ giao hàng'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm địa chỉ mới'),
        backgroundColor: AppTheme.goldColor,
      ),
      body: FutureBuilder<List<AddressItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được địa chỉ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                ),
              ),
            );
          }

          final addresses = snapshot.data ?? const <AddressItem>[];
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_outlined, size: 46, color: AppTheme.mutedColor),
                    const SizedBox(height: 10),
                    Text(
                      'Bạn chưa có địa chỉ nào',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy thêm địa chỉ để checkout nhanh hơn.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mutedColor,
                          ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm địa chỉ'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.goldColor,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: addresses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Dismissible(
                  key: ValueKey(address.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.blazeColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(address);
                    return false;
                  },
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      title: Row(
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${address.phone}\n${address.formattedAddress}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.mutedColor,
                              ),
                        ),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _openForm(address: address);
                          } else if (value == 'default') {
                            await SupabaseService.setDefaultAddress(address.id);
                            if (mounted) await _refresh();
                          } else if (value == 'delete') {
                            await _confirmDelete(address);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                          PopupMenuItem(value: 'default', child: Text('Đặt làm mặc định')),
                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({
    required this.address,
    required this.onSaved,
  });

  final AddressItem? address;
  final Future<void> Function() onSaved;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
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
    _detailController = TextEditingController(text: address?.detailAddress ?? '');
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

  List<String> get _districts => _province == null ? const [] : VietnamAdministrativeData.districtsOf(_province!);

  List<String> get _wards => _province == null || _district == null
      ? const []
      : VietnamAdministrativeData.wardsOf(_province!, _district!);

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final detail = _detailController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        _province == null ||
        _district == null ||
        _ward == null ||
        detail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ thông tin địa chỉ')),
      );
      return;
    }

    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số điện thoại phải là 10 số và bắt đầu bằng 0')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.saveAddress(
        AddressItem(
          id: widget.address?.id ?? '',
          userId: widget.address?.userId ?? '',
          fullName: name,
          phone: phone,
          province: _province!,
          district: _district!,
          ward: _ward!,
          detailAddress: detail,
          isDefault: _isDefault,
          createdAt: widget.address?.createdAt ?? DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
                widget.address == null ? 'Thêm địa chỉ mới' : 'Chỉnh sửa địa chỉ',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              _field('Họ tên người nhận', controller: _nameController),
              _field('Số điện thoại', controller: _phoneController, keyboardType: TextInputType.phone),
              DropdownButtonFormField<String>(
                initialValue: _province,
                decoration: const InputDecoration(labelText: 'Tỉnh / Thành'),
                items: VietnamAdministrativeData.provinces
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
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
                decoration: const InputDecoration(labelText: 'Quận / Huyện'),
                items: _districts
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
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
                decoration: const InputDecoration(labelText: 'Phường / Xã'),
                items: _wards
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: _district == null
                    ? null
                    : (value) => setState(() => _ward = value),
              ),
              const SizedBox(height: 10),
              _field('Địa chỉ chi tiết', controller: _detailController, maxLines: 2),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value ?? false),
                title: const Text('Đặt làm mặc định'),
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
    );
  }

  Widget _field(
    String label, {
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
