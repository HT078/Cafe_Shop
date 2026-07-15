import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/account_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/theme.dart';

class BecomeAgentScreen extends StatefulWidget {
  const BecomeAgentScreen({super.key});

  @override
  State<BecomeAgentScreen> createState() => _BecomeAgentScreenState();
}

class _BecomeAgentScreenState extends State<BecomeAgentScreen> {
  static const _volumeOptions = ['Dưới 5kg', '5-20kg', '20-50kg', 'Trên 50kg'];

  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  String _expectedVolume = _volumeOptions[1];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final account = context.read<AccountProvider>();
    await account.load(force: true);
    if (!mounted) return;

    final profile = account.profile;
    _businessNameController.text = profile.businessName;
    _businessAddressController.text = profile.businessAddress;
    _phoneController.text = profile.businessPhone.isNotEmpty
        ? profile.businessPhone
        : profile.phone;
    _noteController.text = profile.wholesaleNote;
    _expectedVolume = _volumeOptions.contains(profile.expectedVolume)
        ? profile.expectedVolume
        : _volumeOptions[1];

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AccountProvider>().submitWholesaleRegistration(
        businessName: _businessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        businessPhone: _phoneController.text.trim(),
        expectedVolume: _expectedVolume,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      await context.read<AuthProvider>().refreshCurrentUser();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã gửi đăng ký, chúng tôi sẽ liên hệ bạn trong 24h'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetRejected() async {
    await context.read<AccountProvider>().resetWholesaleRegistration();
    if (!mounted) return;
    await context.read<AuthProvider>().refreshCurrentUser();
  }

  Future<void> _showWholesalePriceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bảng giá sỉ'),
        content: const Text(
          'Bảng giá sỉ đang được cập nhật. Nhân viên Hải Tín sẽ gửi chi tiết qua số điện thoại đã đăng ký.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.pageColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.goldColor),
        ),
      );
    }

    final profile = context.watch<AccountProvider>().profile;
    final status = profile.wholesaleStatus;

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      appBar: AppBar(
        title: const Text('Đăng ký làm Khách Sỉ'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          if (status == 'pending')
            const _PendingCard()
          else if (status == 'approved')
            _ApprovedView(onShowPrices: _showWholesalePriceDialog)
          else if (status == 'rejected') ...[
            _RejectedCard(
              reason: profile.rejectReason?.isNotEmpty == true
                  ? profile.rejectReason!
                  : 'Thông tin không đủ điều kiện',
              onRetry: _resetRejected,
            ),
          ] else ...[
            const _BenefitCard(),
            const SizedBox(height: 14),
            _RegistrationForm(
              formKey: _formKey,
              businessNameController: _businessNameController,
              businessAddressController: _businessAddressController,
              phoneController: _phoneController,
              noteController: _noteController,
              expectedVolume: _expectedVolume,
              volumeOptions: _volumeOptions,
              saving: _saving,
              onVolumeChanged: (value) {
                if (value == null) return;
                setState(() => _expectedVolume = value);
              },
              onSubmit: _submit,
              requiredValidator: _required,
              phoneValidator: _phoneValidator,
            ),
            const SizedBox(height: 14),
            const _BenefitItem(
              icon: Icons.sell_outlined,
              label: 'Chiết khấu theo sản lượng nhập mỗi tháng',
            ),
            const SizedBox(height: 10),
            const _BenefitItem(
              icon: Icons.local_shipping_outlined,
              label: 'Ưu tiên xử lý đơn hàng và cập nhật trạng thái sớm',
            ),
            const SizedBox(height: 10),
            const _BenefitItem(
              icon: Icons.support_agent_outlined,
              label: 'Có nhân viên hỗ trợ riêng khi cần báo giá',
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.flameGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppTheme.charColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ưu đãi dành cho Khách Sỉ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Giá ưu đãi dành riêng cho đại lý, chiết khấu theo sản lượng và hỗ trợ tư vấn trực tiếp.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationForm extends StatelessWidget {
  const _RegistrationForm({
    required this.formKey,
    required this.businessNameController,
    required this.businessAddressController,
    required this.phoneController,
    required this.noteController,
    required this.expectedVolume,
    required this.volumeOptions,
    required this.saving,
    required this.onVolumeChanged,
    required this.onSubmit,
    required this.requiredValidator,
    required this.phoneValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController businessNameController;
  final TextEditingController businessAddressController;
  final TextEditingController phoneController;
  final TextEditingController noteController;
  final String expectedVolume;
  final List<String> volumeOptions;
  final bool saving;
  final ValueChanged<String?> onVolumeChanged;
  final VoidCallback onSubmit;
  final String? Function(String?) requiredValidator;
  final String? Function(String?) phoneValidator;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: businessNameController,
                validator: requiredValidator,
                decoration: const InputDecoration(
                  labelText: 'Tên cửa hàng / đại lý',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: businessAddressController,
                validator: requiredValidator,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ kinh doanh',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                validator: phoneValidator,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại kinh doanh',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: expectedVolume,
                decoration: const InputDecoration(
                  labelText: 'Sản lượng dự kiến mỗi tháng',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
                items: volumeOptions
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: onVolumeChanged,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                maxLength: 300,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 6),
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
                    onPressed: saving ? null : onSubmit,
                    child: Text(
                      saving ? 'Đang gửi...' : 'Gửi đăng ký',
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
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceAltColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.goldColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.creamColor),
          ),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: AppTheme.goldColor,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đơn đăng ký của bạn đang được xem xét. Chúng tôi sẽ liên hệ trong vòng 24 giờ.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.creamColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovedView extends StatelessWidget {
  const _ApprovedView({required this.onShowPrices});

  final VoidCallback onShowPrices;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'Tài khoản Khách Sỉ đã được kích hoạt',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Giá sỉ hiện đang được áp dụng tự động khi bạn thêm sản phẩm vào giỏ hàng.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onShowPrices,
              icon: const Icon(Icons.price_check_outlined),
              label: const Text('Xem bảng giá sỉ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedCard extends StatelessWidget {
  const _RejectedCard({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đã từ chối khách sỉ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              reason,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Đăng ký lại'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
