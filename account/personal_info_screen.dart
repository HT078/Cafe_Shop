import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/account_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateFormatter = DateFormat('dd/MM/yyyy');

  DateTime? _dateOfBirth;
  String? _gender;
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
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _emailController.text = profile.email;
    _dateOfBirth = profile.dateOfBirth;
    _gender = profile.gender;

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi ảnh đại diện'),
        content: const Text('Chức năng đang phát triển.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: now,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AccountProvider>().updatePersonalInfo(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
      );
      if (!mounted) return;
      await context.read<AuthProvider>().refreshCurrentUser();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email không hợp lệ';
    }
    return null;
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

    return Scaffold(
      backgroundColor: AppTheme.pageColor,
      appBar: AppBar(title: const Text('Thông tin cá nhân'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(56),
                onTap: _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 54,
                      backgroundColor: AppTheme.surfaceAltColor,
                      child: Icon(
                        Icons.person_rounded,
                        size: 58,
                        color: AppTheme.goldColor,
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.flameGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppTheme.charColor,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.lineColor),
                gradient: AppTheme.cardGlowGradient,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: AppTheme.goldColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hồ sơ tài khoản',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cập nhật thông tin liên hệ để đặt hàng và giao hàng thuận tiện hơn.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: _phoneValidator,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày sinh',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        child: Text(
                          _dateOfBirth == null
                              ? 'Chưa chọn'
                              : _dateFormatter.format(_dateOfBirth!),
                          style: TextStyle(
                            color: _dateOfBirth == null
                                ? AppTheme.mutedColor
                                : AppTheme.creamColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Giới tính',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.mutedColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    RadioGroup<String>(
                      groupValue: _gender,
                      onChanged: (value) => setState(() => _gender = value),
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            value: 'Nam',
                            title: Text('Nam'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            value: 'Nữ',
                            title: Text('Nữ'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<String>(
                            value: 'Khác',
                            title: Text('Khác'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
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
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Đang lưu...' : 'Lưu thay đổi',
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
    );
  }
}
