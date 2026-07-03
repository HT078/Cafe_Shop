import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../screens/admin/admin_guard_screen.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../widgets/customer/brand_logo.dart';
import '../customer/customer_root_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    await _runAuth(
      () => AuthService.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  Future<void> _signInGoogle() async {
    await _runAuth(AuthService.signInWithGoogle);
  }

  Future<void> _runAuth(Future<AuthResponse?> Function() action) async {
    setState(() => _isLoading = true);
    try {
      final response = await action();
      if (response == null) return;
      if (!mounted) return;
      await context.read<AuthProvider>().refreshCurrentUser();
      if (!mounted) return;
      context.read<CartProvider>().setAgentPricing(
            context.read<AuthProvider>().isAgent,
          );
      await context.read<CartProvider>().syncWithCurrentUser();
      if (!mounted) return;
      final isAdmin = context.read<AuthProvider>().isAdmin;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => isAdmin
              ? const AdminGuardScreen()
              : const CustomerRootScreen(),
        ),
        (_) => false,
      );
    } on AuthException catch (error) {
      _showError(_friendlyAuthError(error.message));
    } catch (error, stackTrace) {
      debugPrint('LoginScreen._runAuth failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showError('Đăng nhập thất bại: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('email not confirmed')) {
      return 'Tài khoản chưa xác nhận email. Hãy mở Gmail và bấm link xác nhận từ Supabase.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    return message;
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const _AuthLogo(),
            const SizedBox(height: 34),
            Text(
              'Đăng nhập',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
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
            ),
            const SizedBox(height: 22),
            _GradientButton(
              label: _isLoading ? 'Đang xử lý...' : 'Đăng nhập',
              onPressed: _isLoading ? null : _signIn,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.creamColor,
                foregroundColor: AppTheme.charColor,
                side: const BorderSide(color: AppTheme.creamColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isLoading ? null : _signInGoogle,
              icon: const Text(
                'G',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              label: const Text(
                'Đăng nhập với Google',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text('Chưa có tài khoản? Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandLogo(size: 88, borderRadius: 24),
        const SizedBox(height: 14),
        Text(
          'Cà Phê Hải Tín',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          'Phượng Hoàng Lửa',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.goldColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.charColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
