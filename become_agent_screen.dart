import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';

class BecomeAgentScreen extends StatefulWidget {
  const BecomeAgentScreen({super.key});

  @override
  State<BecomeAgentScreen> createState() => _BecomeAgentScreenState();
}

class _BecomeAgentScreenState extends State<BecomeAgentScreen> {
  late Future<Map<String, dynamic>?> _future;
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final profile = await SupabaseService.fetchProfile();
    _businessNameController.text = (profile?['business_name'] ?? '').toString();
    _businessAddressController.text = (profile?['business_address'] ?? '').toString();
    _phoneController.text = (profile?['phone'] ?? '').toString();
    _noteController.text = (profile?['agent_note'] ?? '').toString();
    return profile;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _submit({required bool resend}) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final businessName = _businessNameController.text.trim();
    final businessAddress = _businessAddressController.text.trim();
    final phone = _phoneController.text.trim();
    final note = _noteController.text.trim();

    if (businessName.isEmpty || businessAddress.isEmpty || phone.isEmpty || note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin khách sỉ')),
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
      await SupabaseService.updateProfileById(
        user.id,
        {
          'business_name': businessName,
          'business_address': businessAddress,
          'phone': phone,
          'agent_note': note,
          'agent_status': 'pending',
          'is_agent': false,
          'reject_reason': null,
          'agent_requested_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      if (!mounted) return;
      await auth.refreshCurrentUser();
      await _refresh();
      messenger.showSnackBar(
        SnackBar(content: Text(resend ? 'Đã gửi lại yêu cầu khách sỉ' : 'Đã gửi yêu cầu khách sỉ')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return 'Chưa có';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _statusCard(Map<String, dynamic>? profile) {
    final status = (profile?['agent_status'] ?? 'none').toString();

    if (status == 'approved') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3A1710), Color(0xFFFFB547), Color(0xFFC81E2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn đã là Khách Sỉ',
              style: TextStyle(
                color: AppTheme.charColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Được duyệt từ: ${_formatDate(profile?['agent_approved_at'] ?? profile?['updated_at'])}',
              style: const TextStyle(color: AppTheme.charColor),
            ),
          ],
        ),
      );
    }

    if (status == 'pending') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yêu cầu của bạn đang được xét duyệt',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Ngày gửi: ${_formatDate(profile?['agent_requested_at'] ?? profile?['updated_at'])}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'rejected') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yêu cầu đã bị từ chối',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent),
              ),
              const SizedBox(height: 6),
              Text(
                (profile?['reject_reason'] ?? 'Chưa có lý do').toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Bạn có thể chỉnh sửa thông tin và gửi lại yêu cầu từ đầu.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        title: const Text('Đăng ký làm Khách Sỉ'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            );
          }

          final profile = snapshot.data;
          final status = (profile?['agent_status'] ?? 'none').toString();
          final canEdit = status != 'pending' && status != 'approved';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusCard(profile),
                if (status != 'approved') ...[
                  const SizedBox(height: 14),
                  Text(
                    'Thông tin đăng ký',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _field('Tên cửa hàng / cơ sở kinh doanh', controller: _businessNameController, enabled: canEdit),
                  _field('Địa chỉ kinh doanh', controller: _businessAddressController, enabled: canEdit),
                  _field('Số điện thoại liên hệ', controller: _phoneController, enabled: canEdit, keyboardType: TextInputType.phone),
                  _field(
                    'Lý do / mô tả nhu cầu nhập sỉ',
                    controller: _noteController,
                    enabled: canEdit,
                    maxLines: 4,
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
                        onPressed: _saving || !canEdit
                            ? null
                            : () => _submit(resend: status == 'rejected'),
                        child: Text(
                          _saving
                              ? 'Đang gửi...'
                              : status == 'rejected'
                                  ? 'Gửi lại yêu cầu'
                                  : 'Gửi yêu cầu',
                          style: const TextStyle(
                            color: AppTheme.charColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (status == 'pending') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Trong thời gian chờ duyệt, bạn vẫn có thể chỉnh sửa thông tin để lần gửi sau đầy đủ hơn.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedColor,
                        ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    String label, {
    required TextEditingController controller,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
