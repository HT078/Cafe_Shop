import 'package:flutter/material.dart';

import '../../screens/auth/login_screen.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';

Future<bool> requireLogin(BuildContext context) async {
  if (SupabaseService.currentUser != null) return true;

  if (!context.mounted) return false;
  final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Vui lòng đăng nhập để tiếp tục'),
          content: const Text(
            'Bạn cần đăng nhập để thanh toán và theo dõi đơn hàng.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Để sau'),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppTheme.flameGradient,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Đăng nhập',
                  style: TextStyle(
                    color: AppTheme.charColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;

  if (shouldLogin && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  return false;
}
