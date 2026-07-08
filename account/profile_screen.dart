import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_routes.dart';
import '../../../models/cart_item_model.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/theme.dart';
import '../../auth/login_screen.dart';

Future<void> _openAndRefresh(BuildContext context, String routeName) async {
  await Navigator.of(context).pushNamed(routeName);
  if (!context.mounted) return;
  await context.read<AuthProvider>().refreshCurrentUser();
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const _tabs = [
    'Chờ duyệt',
    'Đang đóng gói',
    'Đang giao',
    'Lịch sử mua',
  ];

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AccountProvider>().load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final account = context.watch<AccountProvider>();

    return DefaultTabController(
      length: ProfileScreen._tabs.length,
      child: Scaffold(
        backgroundColor: AppTheme.charColor,
        appBar: AppBar(
          title: const Text('Tài Khoản & Đơn Hàng'),
          centerTitle: true,
          actions: [
            if (auth.isAdmin)
              IconButton(
                tooltip: 'Quản trị',
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                onPressed: () => Navigator.of(context).pushNamed('/admin'),
              ),
          ],
        ),
        body: Column(
          children: [
            _ProfileHeader(auth: auth, account: account),
            _AgentBanner(auth: auth, account: account),
            const _QuickMenu(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Đơn hàng của tôi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const TabBar(
              isScrollable: true,
              labelColor: AppTheme.goldColor,
              unselectedLabelColor: AppTheme.mutedColor,
              indicatorColor: AppTheme.emberColor,
              tabs: [
                Tab(text: 'Chờ duyệt'),
                Tab(text: 'Đang đóng gói'),
                Tab(text: 'Đang giao'),
                Tab(text: 'Lịch sử mua'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: ProfileScreen._tabs
                    .map((status) => _OrderList(status: status))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.auth, required this.account});

  final AuthProvider auth;
  final AccountProvider account;

  @override
  Widget build(BuildContext context) {
    final profile = account.profile;
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : auth.fullName.isEmpty
        ? (SupabaseService.currentUser?.email ?? 'Khách Hải Tín')
        : auth.fullName;
    final phone = profile.phone.isNotEmpty
        ? profile.phone
        : auth.phone.isEmpty
        ? 'Chưa cập nhật số điện thoại'
        : auth.phone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.lineColor),
          gradient: AppTheme.cardGlowGradient,
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.goldColor.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 36,
                color: AppTheme.goldColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phone,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý hồ sơ, địa chỉ và trạng thái đơn hàng của bạn.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (auth.isAgent || profile.isWholesaleCustomer)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  gradient: AppTheme.flameGradient,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: const Text(
                  'ĐẠI LÝ',
                  style: TextStyle(
                    color: AppTheme.charColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgentBanner extends StatelessWidget {
  const _AgentBanner({required this.auth, required this.account});

  final AuthProvider auth;
  final AccountProvider account;

  @override
  Widget build(BuildContext context) {
    final profile = account.profile;
    final status = profile.wholesaleStatus ?? auth.agentStatus;
    final rejectReason = profile.rejectReason ?? auth.rejectReason;

    if (status == null) {
      return const SizedBox.shrink();
    }

    if (status == 'approved') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
        ),
        child: Text(
          'Tài khoản khách sỉ đã được duyệt.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.goldColor),
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.orangeAccent.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          'Đang chờ duyệt khách sỉ',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.orangeAccent),
        ),
      );
    }

    if (status != 'rejected') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blazeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.blazeColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        rejectReason == null || rejectReason.isEmpty
            ? 'Đã từ chối khách sỉ'
            : 'Từ chối: $rejectReason',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
      ),
    );
  }
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu();

  Future<void> _signOut(BuildContext context) async {
    context.read<CartProvider>().clear();
    context.read<AuthProvider>().clear();
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.badge_outlined,
        'Thông tin cá nhân',
        () => _openAndRefresh(context, AppRoutes.personalInfo),
      ),
      (
        Icons.location_on_outlined,
        'Địa chỉ giao hàng',
        () => _openAndRefresh(context, AppRoutes.shippingAddress),
      ),
      (
        Icons.workspace_premium_outlined,
        'Đăng ký làm Khách Sỉ',
        () => _openAndRefresh(context, AppRoutes.wholesaleRegistration),
      ),
      (Icons.logout_rounded, 'Đăng xuất', () => _signOut(context)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Card(
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            return Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAltColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$1, color: AppTheme.goldColor, size: 20),
                  ),
                  title: Text(item.$2),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.mutedColor,
                  ),
                  onTap: item.$3,
                ),
                if (index != items.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _OrderList extends StatefulWidget {
  const _OrderList({required this.status});

  final String status;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchCustomerOrdersByTab(widget.status);
  }

  Future<void> _retry() async {
    setState(() {
      _future = SupabaseService.fetchCustomerOrdersByTab(widget.status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.goldColor),
          );
        }

        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Không tải được đơn hàng',
            subtitle: 'Có thể do kết nối hoặc RLS đang chặn truy vấn.',
            actionLabel: 'Thử lại',
            onAction: _retry,
          );
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const _EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Chưa có đơn hàng nào',
            subtitle: 'Khi bạn đặt hàng, các đơn sẽ hiện ở đây.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _OrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 46, color: AppTheme.mutedColor),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  _OrderCard({required this.order});

  final Map<String, dynamic> order;
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  String _money(dynamic value) {
    final amount = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return '${_currency.format(amount)}đ';
  }

  List<Map<String, dynamic>> get _items {
    final raw = order['order_items'];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? '').toString();
    final isHistory =
        status == 'Lịch sử mua' || status == 'Đã giao' || status == 'Hoàn tất';
    final date = DateTime.tryParse((order['created_at'] ?? '').toString());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đơn ${order['id']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ngày đặt: ${date == null ? '' : DateFormat('dd/MM/yyyy').format(date)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              Text(
                'Không có chi tiết sản phẩm',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item['product_name'] ?? item['name'] ?? 'Sản phẩm'} x${item['quantity'] ?? 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(order['total']),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.goldColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showOrderDetail(context, order),
                  child: const Text('Xem chi tiết'),
                ),
                if (isHistory)
                  TextButton(
                    onPressed: () => _buyAgain(context, _items),
                    child: const Text('Mua lại'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyAgain(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) async {
    final products = context.read<ProductProvider>().products;
    final cartItems = <CartItem>[];

    for (final item in items) {
      final productId = item['product_id']?.toString();
      final index = products.indexWhere((product) => product.id == productId);
      if (index < 0) continue;

      cartItems.add(
        CartItem(
          product: products[index],
          quantity: item['quantity'] is int
              ? item['quantity'] as int
              : int.tryParse(item['quantity']?.toString() ?? '') ?? 1,
          weight:
              (item['weight'] ??
                      (products[index].weights.isEmpty
                          ? '500g'
                          : products[index].weights.first))
                  .toString(),
          grindType:
              (item['grind_type'] ??
                      (products[index].grindOptions.isEmpty
                          ? 'Xay pha phin'
                          : products[index].grindOptions.first))
                  .toString(),
        ),
      );
    }

    await context.read<CartProvider>().addItems(cartItems);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cartItems.isEmpty
              ? 'Không tìm thấy sản phẩm để mua lại'
              : 'Đã thêm lại đơn hàng vào giỏ',
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color get _color {
    return switch (status) {
      'Chờ duyệt' => AppTheme.goldColor,
      'Đang đóng gói' => AppTheme.emberColor,
      'Đang giao' => Colors.lightBlueAccent,
      _ => Colors.greenAccent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.isEmpty ? 'Đang cập nhật' : status,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

void _showOrderDetail(BuildContext context, Map<String, dynamic> order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, controller) =>
          _OrderDetailSheet(order: order, controller: controller),
    ),
  );
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order, required this.controller});

  final Map<String, dynamic> order;
  final ScrollController controller;

  int get _currentStep {
    return switch ((order['status'] ?? '').toString()) {
      'Chờ duyệt' => 1,
      'Đang đóng gói' => 2,
      'Đang giao' => 3,
      _ => 4,
    };
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Đặt hàng', 'Xác nhận', 'Đóng gói', 'Đang giao', 'Đã giao'];

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.lineColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Chi tiết đơn ${order['id']}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        _DetailLine(
          label: 'Mã vận đơn',
          value: (order['tracking_code'] ?? 'Đang chờ tạo vận đơn').toString(),
        ),
        _DetailLine(
          label: 'Đơn vị vận chuyển',
          value: (order['carrier'] ?? 'Hải Tín Delivery').toString(),
        ),
        const SizedBox(height: 12),
        Stepper(
          currentStep: _currentStep,
          physics: const NeverScrollableScrollPhysics(),
          controlsBuilder: (context, details) => const SizedBox.shrink(),
          steps: List.generate(steps.length, (index) {
            final active = index <= _currentStep;
            return Step(
              title: Text(steps[index]),
              content: Text(
                active ? 'Đã cập nhật trạng thái' : 'Đang chờ xử lý',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
              ),
              isActive: active,
              state: index < _currentStep
                  ? StepState.complete
                  : StepState.indexed,
            );
          }),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
