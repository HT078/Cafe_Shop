import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../screens/admin/admin_guard_screen.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';
import '../../widgets/customer/brand_logo.dart';
import '../customer/customer_root_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openNext();
  }

  // Kiểm tra session Supabase để điều hướng ban đầu.
  Future<void> _openNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    var user = SupabaseService.currentUser;
    if (user != null) {
      try {
        await AuthService.syncCurrentUserProfile();
        if (!mounted) return;
        await context.read<AuthProvider>().refreshCurrentUser();
        if (!mounted) return;
        context.read<CartProvider>().setAgentPricing(
              context.read<AuthProvider>().isAgent,
            );
        await context.read<CartProvider>().syncWithCurrentUser();
        if (!mounted) return;
      } catch (error) {
        debugPrint('SplashScreen._openNext failed: $error');
        if (!mounted) return;
        await context.read<AuthProvider>().refreshCurrentUser();
        if (!mounted) return;
        user = SupabaseService.currentUser;
      }
    }

    if (!mounted) return;
    final isAdmin = context.read<AuthProvider>().isAdmin;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user == null
            ? const LoginScreen()
            : isAdmin
                ? const AdminGuardScreen()
                : const CustomerRootScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.charColor,
      body: Center(
        child: BrandLogo(size: 112, color: AppTheme.lightTextColor),
      ),
    );
  }
}
