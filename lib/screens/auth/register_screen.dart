import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/cart_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../utils/validators.dart';
import '../customer/customer_root_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final response = await AuthService.signUp(
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đăng ký thành công. Hãy kiểm tra Gmail ${_emailController.text.trim()} để xác nhận tài khoản.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        Navigator.of(context).pop();
      } else {
        await context.read<CartProvider>().syncWithCurrentUser();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomerRootScreen()),
          (_) => false,
        );
      }
    } on AuthException catch (error) {
      _showError(_friendlyAuthError(error.message));
    } catch (_) {
      _showError('Đăng ký thất bại, vui lòng kiểm tra lại thông tin');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('user already registered')) {
      return 'Email này đã đăng ký. Hãy đăng nhập hoặc kiểm tra email xác nhận.';
    }
    return message;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!RegExp(r'^[0-9]{9,11}$').hasMatch(phone)) {
      return 'Số điện thoại phải gồm 9-11 chữ số';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.blazeColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(title: const Text('Đăng Ký'), centerTitle: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Họ tên',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Vui lòng nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mật khẩu tối thiểu 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (value) => value == _passwordController.text
                    ? null
                    : 'Mật khẩu xác nhận không khớp',
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 24),
              Container(
                height: 52,
                decoration: const BoxDecoration(
                  gradient: AppTheme.flameGradient,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: _isLoading ? null : _register,
                  child: Text(
                    _isLoading ? 'Đang tạo tài khoản...' : 'Đăng ký',
                    style: const TextStyle(
                      color: AppTheme.charColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mật khẩu được lưu bảo mật bởi Supabase Auth. Số điện thoại được lưu trong hồ sơ khách hàng.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
