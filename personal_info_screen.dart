import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late Future<Map<String, dynamic>?> _future;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final profile = await SupabaseService.fetchProfile();
    final user = SupabaseService.currentUser;

    _fullNameController.text = (profile?['full_name'] ?? '').toString();
    _phoneController.text = (profile?['phone'] ?? '').toString();
    _emailController.text = user?.email ?? '';
    _dateOfBirth = DateTime.tryParse((profile?['date_of_birth'] ?? '').toString());
    _gender = (profile?['gender'] ?? '').toString().trim().isEmpty ? null : profile?['gender'].toString();

    return profile;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDate: _dateOfBirth ?? DateTime(1995),
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập họ tên')),
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
          'full_name': fullName,
          'phone': phone,
          'date_of_birth': _dateOfBirth?.toIso8601String(),
          'gender': _gender,
          'email': user.email,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      if (!mounted) return;
      await auth.refreshCurrentUser();
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hồ sơ tài khoản',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _field('Họ tên', controller: _fullNameController),
                        _field('Số điện thoại', controller: _phoneController, keyboardType: TextInputType.phone),
                        _field('Email', controller: _emailController, enabled: false),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ngày sinh'),
                          subtitle: Text(
                            _dateOfBirth == null ? 'Chưa chọn' : DateFormat('dd/MM/yyyy').format(_dateOfBirth!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.mutedColor,
                                ),
                          ),
                          trailing: IconButton(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String?>(
                          initialValue: _gender,
                          decoration: const InputDecoration(labelText: 'Giới tính'),
                          items: const [
                            DropdownMenuItem<String?>(value: null, child: Text('Chưa chọn')),
                            DropdownMenuItem<String?>(value: 'Nam', child: Text('Nam')),
                            DropdownMenuItem<String?>(value: 'Nữ', child: Text('Nữ')),
                            DropdownMenuItem<String?>(value: 'Khác', child: Text('Khác')),
                          ],
                          onChanged: (value) => setState(() => _gender = value),
                        ),
                        const SizedBox(height: 18),
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
                ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
