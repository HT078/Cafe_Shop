import 'package:flutter/material.dart';

import '../../../services/admin_service.dart';
import '../../../theme/theme.dart';

class AgentManageScreen extends StatefulWidget {
  const AgentManageScreen({super.key});

  @override
  State<AgentManageScreen> createState() => _AgentManageScreenState();
}

class _AgentManageScreenState extends State<AgentManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  final _tabs = const [
    ('pending', 'Chờ duyệt'),
    ('approved', 'Đã duyệt'),
    ('rejected', 'Từ chối'),
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

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _rejectAgent(Map<String, dynamic> agent) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối khách sỉ'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Lý do',
            hintText: 'Nhập lý do từ chối',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do từ chối')),
      );
      return;
    }

    await AdminService.rejectAgent(agent['id'].toString(), reason);
    await _refresh();
  }

  Widget _buildList(String status) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AdminService.fetchAgents(status),
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

        final agents = snapshot.data ?? const [];
        if (agents.isEmpty) {
          return Center(
            child: Text(
              'Không có dữ liệu',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
            ),
          );
        }

          return RefreshIndicator(
            color: AppTheme.goldColor,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: agents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
              final agent = agents[index];
              final fullName = (agent['full_name'] ?? '').toString().trim();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.surfaceAltColor,
                    child: Icon(Icons.storefront_outlined, color: AppTheme.goldColor),
                  ),
                  title: Text(fullName.isEmpty ? 'Khách sỉ' : fullName),
                  subtitle: Text(
                    [
                      agent['phone']?.toString() ?? '',
                      agent['email']?.toString() ?? '',
                      if ((agent['reject_reason'] ?? '').toString().isNotEmpty)
                        'Lý do: ${agent['reject_reason']}',
                    ].where((value) => value.isNotEmpty).join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: status == 'pending'
                      ? Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Duyệt',
                              onPressed: () async {
                                await AdminService.approveAgent(agent['id'].toString());
                                await _refresh();
                              },
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                            IconButton(
                              tooltip: 'Từ chối',
                              onPressed: () => _rejectAgent(agent),
                              icon: const Icon(Icons.block_outlined),
                            ),
                          ],
                        )
                      : IconButton(
                          tooltip: 'Thu hồi',
                          onPressed: () async {
                            await AdminService.revokeAgent(agent['id'].toString());
                            await _refresh();
                          },
                          icon: const Icon(Icons.undo_outlined),
                        ),
                ),
              );
            },
          ),
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
            labelColor: AppTheme.goldColor,
            unselectedLabelColor: AppTheme.mutedColor,
            indicatorColor: AppTheme.emberColor,
            tabs: _tabs.map((item) => Tab(text: item.$2)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: _tabs.map((item) => _buildList(item.$1)).toList(),
          ),
        ),
      ],
    );
  }
}
