import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../theme/theme.dart';
import '../customer/customer_root_screen.dart';
import 'admin_home_screen.dart';

class AdminGuardScreen extends StatelessWidget {
  const AdminGuardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminService.isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.charColor,
            body: Center(child: CircularProgressIndicator(color: AppTheme.goldColor)),
          );
        }

        if (snapshot.data == true) return const AdminHomeScreen();

        Future.microtask(() {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có quyền truy cập'), backgroundColor: AppTheme.blazeColor),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const CustomerRootScreen()),
            (_) => false,
          );
        });

        return const Scaffold(
          backgroundColor: AppTheme.charColor,
          body: Center(
            child: Text('Không có quyền truy cập', style: TextStyle(color: AppTheme.lightTextColor)),
          ),
        );
      },
    );
  }
}
