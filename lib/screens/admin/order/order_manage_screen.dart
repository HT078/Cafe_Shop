import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/admin_service.dart';
import '../../../../theme/theme.dart';

class OrderManageScreen extends StatefulWidget {
  const OrderManageScreen({super.key});

  @override
  State<OrderManageScreen> createState() => _OrderManageScreenState();
}

class _OrderManageScreenState extends State<OrderManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  final _tabs = const [
    'Chờ duyệt',
    'Đã xác nhận',
    'Đang đóng gói',
    'Đang giao',
    'Đã giao',
    'Đã hủy',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<Map<String, String>?> _askShippingInfo() async {
    final trackingController = TextEditingController();
    final unitController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nhập vận đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trackingController,
              decoration: const InputDecoration(labelText: 'Mã vận đơn'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'Đơn vị vận chuyển'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final tracking = trackingController.text.trim();
              final unit = unitController.text.trim();
              if (tracking.isEmpty || unit.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin vận đơn')),
                );
                return;
              }
              Navigator.of(dialogContext).pop({
                'tracking_code': tracking,
                'shipping_unit': unit,
              });
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Lý do hủy'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do hủy')),
                );
                return;
              }
              Navigator.of(dialogContext).pop(reason);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'Chờ duyệt' => AppTheme.goldColor,
      'Đã xác nhận' => Colors.orangeAccent,
      'Đang đóng gói' => AppTheme.emberColor,
      'Đang giao' => Colors.lightBlueAccent,
      'Đã giao' => Colors.greenAccent,
      'Đã hủy' => AppTheme.blazeColor,
      _ => AppTheme.mutedColor,
    };
  }

  Future<void> _updateOrder(Map<String, dynamic> order, String nextStatus) async {
    final orderId = order['id'].toString();
    if (nextStatus == 'Đang giao') {
      final info = await _askShippingInfo();
      if (info == null) return;
      await AdminService.updateOrderStatus(
        orderId,
        nextStatus,
        trackingCode: info['tracking_code'],
        shippingUnit: info['shipping_unit'],
      );
    } else if (nextStatus == 'Đã hủy') {
      final reason = await _askCancelReason();
      if (reason == null) return;
      await AdminService.updateOrderStatus(
        orderId,
        nextStatus,
        cancelReason: reason,
      );
    } else if (nextStatus == 'Đã giao') {
      await AdminService.markDelivered(orderId);
    } else {
      await AdminService.updateOrderStatus(orderId, nextStatus);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật trạng thái đơn hàng')),
    );
    setState(() {});
  }

  Widget _buildActions(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString();
    final buttons = <Widget>[];

    if (status == 'Chờ duyệt') {
      buttons.add(
        TextButton(
          onPressed: () => _updateOrder(order, 'Đã xác nhận'),
          child: const Text('Xác nhận'),
        ),
      );
    }
    if (status == 'Đã xác nhận') {
      buttons.add(
        TextButton(
          onPressed: () => _updateOrder(order, 'Đang đóng gói'),
          child: const Text('Đóng gói'),
        ),
      );
    }
    if (status == 'Đang đóng gói') {
      buttons.add(
        TextButton(
          onPressed: () => _updateOrder(order, 'Đang giao'),
          child: const Text('Giao hàng'),
        ),
      );
    }
    if (status == 'Đang giao') {
      buttons.add(
        TextButton(
          onPressed: () => _updateOrder(order, 'Đã giao'),
          child: const Text('Đã giao'),
        ),
      );
    }
    if (status == 'Chờ duyệt' || status == 'Đã xác nhận' || status == 'Đang đóng gói') {
      buttons.add(
        TextButton(
          onPressed: () => _updateOrder(order, 'Đã hủy'),
          child: const Text('Hủy đơn'),
        ),
      );
    }

    return Wrap(spacing: 8, children: buttons);
  }

  Future<void> _openDetail(Map<String, dynamic> order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OrderDetailSheet(order: order),
    );
  }

  Widget _buildList(String status) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminService.ordersStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.goldColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              snapshot.error.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final orders = snapshot.data ?? const [];
        if (orders.isEmpty) {
          return Center(
            child: Text(
              'Không có đơn hàng',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
            final statusValue = (order['status'] ?? '').toString();
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
                        _StatusChip(
                          label: statusValue,
                          color: _statusColor(statusValue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt == null
                          ? 'Chưa có ngày đặt'
                          : 'Ngày đặt: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mutedColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tổng tiền: ${NumberFormat('#,##0', 'vi_VN').format(order['total'] ?? 0)}đ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.goldColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _openDetail(order),
                          child: const Text('Xem chi tiết'),
                        ),
                        const Spacer(),
                        _buildActions(order),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            controller: _controller,
            isScrollable: true,
            labelColor: AppTheme.goldColor,
            unselectedLabelColor: AppTheme.mutedColor,
            indicatorColor: AppTheme.emberColor,
            tabs: _tabs.map((item) => Tab(text: item)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: _tabs.map(_buildList).toList(),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final Map<String, dynamic> order;

  int _currentStep(String status) {
    return switch (status) {
      'Chờ duyệt' => 0,
      'Đã xác nhận' => 1,
      'Đang đóng gói' => 2,
      'Đang giao' => 3,
      'Đã giao' => 4,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? '').toString();
    final itemsFuture = AdminService.fetchOrderItems(order['id'].toString());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: itemsFuture,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const [];
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã vận đơn: ${order['tracking_code'] ?? 'Chưa có'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                ),
                Text(
                  'Đơn vị vận chuyển: ${order['shipping_unit'] ?? 'Chưa có'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                ),
                const SizedBox(height: 16),
                Stepper(
                  currentStep: _currentStep(status),
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  steps: const [
                    Step(title: Text('Đặt hàng'), content: SizedBox.shrink()),
                    Step(title: Text('Xác nhận'), content: SizedBox.shrink()),
                    Step(title: Text('Đóng gói'), content: SizedBox.shrink()),
                    Step(title: Text('Đang giao'), content: SizedBox.shrink()),
                    Step(title: Text('Đã giao'), content: SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Sản phẩm trong đơn',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.goldColor),
                    ),
                  )
                else if (items.isEmpty)
                  Text(
                    'Chưa có dữ liệu sản phẩm',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedColor,
                        ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: ListTile(
                          title: Text(item['product_name']?.toString() ?? 'Sản phẩm'),
                          subtitle: Text(
                            '${item['weight'] ?? ''} · ${item['grind_type'] ?? ''} · SL ${item['quantity'] ?? 1}',
                          ),
                          trailing: Text(
                            NumberFormat('#,##0', 'vi_VN').format(item['line_total'] ?? 0),
                            style: const TextStyle(
                              color: AppTheme.goldColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
