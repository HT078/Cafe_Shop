import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/voucher_admin_repository.dart';
import '../../../models/voucher_model.dart';
import '../../../theme/theme.dart';

class VoucherManageScreen extends StatefulWidget {
  const VoucherManageScreen({super.key});

  @override
  State<VoucherManageScreen> createState() => _VoucherManageScreenState();
}

class _VoucherManageScreenState extends State<VoucherManageScreen> {
  final VoucherAdminRepository _repository = VoucherAdminRepository();
  final Set<String> _busyIds = <String>{};

  List<Voucher> _vouchers = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final vouchers = await _repository.getAllVouchers();
      if (!mounted) return;
      setState(() {
        _vouchers = vouchers;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _runAction(
    Voucher voucher,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final id = voucher.id;
    if (id == null || id.isEmpty || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await action();
      await _loadVouchers(showLoading: false);
      if (!mounted) return;
      _showMessage(successMessage, success: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _openForm({Voucher? voucher}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      constraints: const BoxConstraints(maxWidth: 760),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) =>
          _VoucherFormSheet(voucher: voucher, repository: _repository),
    );
    if (saved != true || !mounted) return;
    await _loadVouchers(showLoading: false);
    if (!mounted) return;
    _showMessage(
      voucher == null
          ? 'Đã thêm mã giảm giá mới'
          : 'Đã cập nhật mã ${voucher.code}',
      success: true,
    );
  }

  Future<void> _confirmReset(Voucher voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset lượt sử dụng?'),
        content: Text('Đặt lượt đã dùng của mã ${voucher.code} về 0?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset lượt'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      voucher,
      () => _repository.resetUsedCount(voucher.id!),
      'Đã reset lượt dùng mã ${voucher.code}',
    );
  }

  Future<void> _confirmDelete(Voucher voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa mã ${voucher.code}?'),
        content: const Text('Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Xóa mã'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      voucher,
      () => _repository.deleteVoucher(voucher.id!),
      'Đã xóa mã ${voucher.code}',
    );
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success
              ? const Color(0xFF285B3D)
              : AppTheme.blazeColor,
        ),
      );
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') return 'Mã giảm giá này đã tồn tại';
      if (error.code == '42P01') {
        return 'Chưa có bảng coupons trong Supabase';
      }
      if (error.code == '42501') {
        return 'Tài khoản chưa có quyền quản lý mã giảm giá';
      }
      return 'Supabase: ${error.message}';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm mã'),
      ),
      body: Column(
        children: [
          _VoucherToolbar(
            vouchers: _vouchers,
            onAdd: _isLoading ? null : () => _openForm(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor),
      );
    }
    if (_error != null) {
      return _VoucherErrorState(
        message: _error!,
        onRetry: () => _loadVouchers(),
      );
    }
    if (_vouchers.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.goldColor,
        onRefresh: () => _loadVouchers(showLoading: false),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(
              Icons.local_offer_outlined,
              size: 56,
              color: AppTheme.mutedColor,
            ),
            const SizedBox(height: 14),
            Text(
              'Chưa có mã giảm giá',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo mã đầu tiên'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.goldColor,
      onRefresh: () => _loadVouchers(showLoading: false),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _vouchers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final voucher = _vouchers[index];
          final id = voucher.id ?? '';
          return _VoucherCard(
            voucher: voucher,
            isBusy: _busyIds.contains(id),
            onEdit: () => _openForm(voucher: voucher),
            onDelete: () => _confirmDelete(voucher),
            onReset: () => _confirmReset(voucher),
            onToggle: (value) => _runAction(
              voucher,
              () => _repository.toggleVoucher(id, value),
              value ? 'Đã bật mã ${voucher.code}' : 'Đã tắt mã ${voucher.code}',
            ),
          );
        },
      ),
    );
  }
}

class _VoucherToolbar extends StatelessWidget {
  const _VoucherToolbar({required this.vouchers, required this.onAdd});

  final List<Voucher> vouchers;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final activeCount = vouchers
        .where((voucher) => voucher.status == VoucherStatus.active)
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.lineColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: AppTheme.goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản lý mã giảm giá',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${vouchers.length} mã • $activeCount đang hoạt động',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 600)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm mã'),
            ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({
    required this.voucher,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onReset,
  });

  final Voucher voucher;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final status = _voucherStatusStyle(voucher.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: AppTheme.goldColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    voucher.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.goldColor,
                      ),
                    ),
                  ),
                Switch.adaptive(
                  value: voucher.isActive,
                  onChanged: isBusy ? null : onToggle,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _VoucherBadge(
                  label: voucher.discountLabel,
                  color: AppTheme.goldColor,
                ),
                _VoucherBadge(label: status.label, color: status.color),
                if (voucher.isAgentOnly)
                  const _VoucherBadge(
                    label: 'Khách sỉ',
                    color: AppTheme.emberColor,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _VoucherInfoRow(
              icon: Icons.shopping_cart_outlined,
              text:
                  'Đơn tối thiểu: ${Voucher.formatMoney(voucher.minOrderValue)}',
            ),
            _VoucherInfoRow(
              icon: Icons.repeat_rounded,
              text: voucher.remainingLabel,
            ),
            if (voucher.maxDiscount != null)
              _VoucherInfoRow(
                icon: Icons.price_change_outlined,
                text:
                    'Giảm tối đa: ${Voucher.formatMoney(voucher.maxDiscount!)}',
              ),
            if (voucher.startAt != null || voucher.expiresAt != null)
              _VoucherInfoRow(
                icon: Icons.calendar_today_outlined,
                text: _dateRange(voucher),
              ),
            if ((voucher.description ?? '').isNotEmpty)
              _VoucherInfoRow(
                icon: Icons.info_outline_rounded,
                text: voucher.description!,
              ),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: isBusy ? null : onReset,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Reset lượt'),
                  ),
                  TextButton.icon(
                    onPressed: isBusy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Sửa'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                    ),
                    onPressed: isBusy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Xóa'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateRange(Voucher voucher) {
    final format = DateFormat('dd/MM/yyyy');
    if (voucher.startAt != null && voucher.expiresAt != null) {
      return '${format.format(voucher.startAt!)} – ${format.format(voucher.expiresAt!)}';
    }
    if (voucher.startAt != null) {
      return 'Bắt đầu: ${format.format(voucher.startAt!)}';
    }
    return 'Hết hạn: ${format.format(voucher.expiresAt!)}';
  }
}

class _VoucherBadge extends StatelessWidget {
  const _VoucherBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VoucherInfoRow extends StatelessWidget {
  const _VoucherInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.creamColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherErrorState extends StatelessWidget {
  const _VoucherErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.dangerColor,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherFormSheet extends StatefulWidget {
  const _VoucherFormSheet({required this.repository, this.voucher});

  final VoucherAdminRepository repository;
  final Voucher? voucher;

  @override
  State<_VoucherFormSheet> createState() => _VoucherFormSheetState();
}

class _VoucherFormSheetState extends State<_VoucherFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _valueController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _maxUsesController;
  late final TextEditingController _descriptionController;

  late String _discountType;
  late bool _isAgentOnly;
  DateTime? _startAt;
  DateTime? _expiresAt;
  bool _isSaving = false;
  String? _submitError;

  bool get _isEdit => widget.voucher != null;

  @override
  void initState() {
    super.initState();
    final voucher = widget.voucher;
    _codeController = TextEditingController(text: voucher?.code ?? '');
    _valueController = TextEditingController(
      text: voucher == null ? '' : voucher.discountValue.toString(),
    );
    _minOrderController = TextEditingController(
      text: voucher == null || voucher.minOrderValue == 0
          ? ''
          : voucher.minOrderValue.toString(),
    );
    _maxDiscountController = TextEditingController(
      text: voucher?.maxDiscount?.toString() ?? '',
    );
    _maxUsesController = TextEditingController(
      text: voucher?.maxUses?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: voucher?.description ?? '',
    );
    _discountType = voucher?.discountType ?? 'percent';
    _isAgentOnly = voucher?.isAgentOnly ?? false;
    _startAt = voucher?.startAt;
    _expiresAt = voucher?.expiresAt;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _maxUsesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startAt : _expiresAt;
    final now = DateTime.now();
    final initialDate = current ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startAt = DateTime(picked.year, picked.month, picked.day);
      } else {
        _expiresAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
          999,
        );
      }
      _submitError = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startAt != null &&
        _expiresAt != null &&
        _startAt!.isAfter(_expiresAt!)) {
      setState(() => _submitError = 'Ngày kết thúc phải sau ngày bắt đầu');
      return;
    }

    setState(() {
      _isSaving = true;
      _submitError = null;
    });
    final old = widget.voucher;
    final voucher = Voucher(
      id: old?.id,
      code: _codeController.text.trim().toUpperCase(),
      discountType: _discountType,
      discountValue: int.parse(_valueController.text),
      minOrderValue: int.tryParse(_minOrderController.text) ?? 0,
      maxDiscount: _discountType == 'percent'
          ? int.tryParse(_maxDiscountController.text)
          : null,
      maxUses: int.tryParse(_maxUsesController.text),
      usedCount: old?.usedCount ?? 0,
      isAgentOnly: _isAgentOnly,
      isActive: old?.isActive ?? true,
      startAt: _startAt,
      expiresAt: _expiresAt,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: old?.createdAt,
    );

    try {
      if (_isEdit) {
        await widget.repository.updateVoucher(old!.id!, voucher);
      } else {
        await widget.repository.addVoucher(voucher);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error.code == '23505'
            ? 'Mã này đã tồn tại'
            : 'Supabase: ${error.message}';
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Sửa mã giảm giá' : 'Thêm mã giảm giá',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _codeController,
                      enabled: !_isEdit && !_isSaving,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9_-]'),
                        ),
                        const _UpperCaseTextFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mã voucher *',
                        hintText: 'HAITIN10',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Vui lòng nhập mã voucher';
                        if (text.length < 3) return 'Mã cần ít nhất 3 ký tự';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loại giảm giá',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'percent',
                            icon: Icon(Icons.percent_rounded),
                            label: Text('Theo phần trăm'),
                          ),
                          ButtonSegment(
                            value: 'fixed',
                            icon: Icon(Icons.payments_outlined),
                            label: Text('Số tiền cố định'),
                          ),
                        ],
                        selected: {_discountType},
                        onSelectionChanged: _isSaving
                            ? null
                            : (selection) => setState(() {
                                _discountType = selection.first;
                                _submitError = null;
                              }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ResponsiveFields(
                      children: [
                        TextFormField(
                          controller: _valueController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: _discountType == 'percent'
                                ? 'Giá trị giảm (%) *'
                                : 'Giá trị giảm (VNĐ) *',
                            suffixText: _discountType == 'percent' ? '%' : 'đ',
                          ),
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            if (number == null || number <= 0) {
                              return 'Giá trị phải lớn hơn 0';
                            }
                            if (_discountType == 'percent' && number > 100) {
                              return 'Tối đa 100%';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _minOrderController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Đơn hàng tối thiểu',
                            suffixText: 'đ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFields(
                      children: [
                        if (_discountType == 'percent')
                          TextFormField(
                            controller: _maxDiscountController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Giảm tối đa',
                              suffixText: 'đ',
                            ),
                            validator: _optionalPositiveValidator,
                          ),
                        TextFormField(
                          controller: _maxUsesController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Giới hạn lượt dùng',
                          ),
                          validator: _optionalPositiveValidator,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ResponsiveFields(
                      children: [
                        _VoucherDateField(
                          label: 'Ngày bắt đầu',
                          value: _startAt,
                          enabled: !_isSaving,
                          onPick: () => _pickDate(isStart: true),
                          onClear: () => setState(() => _startAt = null),
                        ),
                        _VoucherDateField(
                          label: 'Ngày hết hạn',
                          value: _expiresAt,
                          enabled: !_isSaving,
                          onPick: () => _pickDate(isStart: false),
                          onClear: () => setState(() => _expiresAt = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: const Text('Chỉ dành cho khách sỉ'),
                      secondary: const Icon(Icons.groups_outlined),
                      value: _isAgentOnly,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _isAgentOnly = value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      maxLines: 2,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả ngắn',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _submitError!,
                        style: const TextStyle(
                          color: AppTheme.dangerColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.charColor,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isEdit ? 'Cập nhật mã' : 'Thêm mã giảm giá',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _optionalPositiveValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null || number <= 0) return 'Giá trị phải lớn hơn 0';
    return null;
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560 || children.length == 1) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _VoucherDateField extends StatelessWidget {
  const _VoucherDateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onPick : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: 'Xóa ngày',
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(
          value == null
              ? 'Không giới hạn'
              : DateFormat('dd/MM/yyyy').format(value!),
          style: TextStyle(
            color: value == null ? AppTheme.mutedColor : AppTheme.creamColor,
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

({String label, Color color}) _voucherStatusStyle(VoucherStatus status) {
  return switch (status) {
    VoucherStatus.active => (
      label: 'Đang hoạt động',
      color: AppTheme.successColor,
    ),
    VoucherStatus.disabled => (label: 'Đã tắt', color: AppTheme.mutedColor),
    VoucherStatus.scheduled => (
      label: 'Sắp diễn ra',
      color: AppTheme.goldColor,
    ),
    VoucherStatus.expired => (label: 'Hết hạn', color: AppTheme.dangerColor),
    VoucherStatus.full => (label: 'Hết lượt', color: AppTheme.warningColor),
  };
}
