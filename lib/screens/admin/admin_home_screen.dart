import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/theme.dart';
import '../auth/login_screen.dart';
import '../customer/customer_root_screen.dart';
import 'agent_manage_screen.dart';
import 'banner_manage_screen.dart';
import 'chat_manage_screen.dart';
import 'order_manage_screen.dart';
import 'product_manage_screen.dart';
import 'sales_report_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;
  StreamSubscription<AuthState>? _authSubscription;

  final _screens = const [
    _AdminOverview(),
    BannerManageScreen(),
    ProductManageScreen(),
    OrderManageScreen(),
    AgentManageScreen(),
    ChatManageScreen(),
    SalesReportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (_) => _refreshAdminSession(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAdminSession());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshAdminSession() async {
    if (!mounted) return;
    await context.read<AuthProvider>().refreshCurrentUser();
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (SupabaseService.currentUser == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }

    if (!auth.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tài khoản ${auth.email} không có quyền admin'),
          backgroundColor: AppTheme.blazeColor,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CustomerRootScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn muốn đăng xuất khỏi trang quản trị?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    context.read<CartProvider>().clear();
    context.read<AuthProvider>().clear();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quản trị Hải Tín'),
            Text(
              '${auth.email.isEmpty ? 'Chưa đăng nhập' : auth.email} • ${auth.role}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.goldColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            label: 'Banner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Sản phẩm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: 'Khách sỉ',
          ),
          BottomNavigationBarItem(icon: _AdminChatNavIcon(), label: 'Chat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Báo cáo',
          ),
        ],
      ),
    );
  }
}

class _AdminChatNavIcon extends StatefulWidget {
  const _AdminChatNavIcon();

  @override
  State<_AdminChatNavIcon> createState() => _AdminChatNavIconState();
}

class _AdminChatNavIconState extends State<_AdminChatNavIcon> {
  int _waitingCount = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadWaitingCount();
      _subscribeWaitingCount();
    });
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _loadWaitingCount() async {
    try {
      final count = await ChatService.fetchWaitingAdminCount();
      if (!mounted) return;
      setState(() => _waitingCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _waitingCount = 0);
    }
  }

  // Badge realtime số hội thoại cần admin hỗ trợ.
  void _subscribeWaitingCount() {
    _channel = SupabaseService.client
        .channel('admin_waiting_chat_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _loadWaitingCount(),
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline_rounded),
        if (_waitingCount > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.blazeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _waitingCount > 99 ? '99+' : '$_waitingCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'vi_VN');
    return FutureBuilder<AdminStats>(
      future: AdminService.fetchStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.goldColor),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Không tải được thống kê',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final stats =
            snapshot.data ??
            const AdminStats(
              pendingToday: 0,
              revenueToday: 0,
              lowStockCount: 0,
            );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StatTile(
              icon: Icons.pending_actions_rounded,
              label: 'Đơn chờ duyệt hôm nay',
              value: '${stats.pendingToday}',
              color: AppTheme.goldColor,
            ),
            const SizedBox(height: 12),
            _StatTile(
              icon: Icons.payments_outlined,
              label: 'Doanh thu hôm nay',
              value: '${currency.format(stats.revenueToday)}đ',
              color: AppTheme.emberColor,
            ),
            const SizedBox(height: 12),
            _StatTile(
              icon: Icons.warning_amber_rounded,
              label: 'Sản phẩm sắp hết hàng',
              value: '${stats.lowStockCount}',
              color: Colors.orangeAccent,
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.goldColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
