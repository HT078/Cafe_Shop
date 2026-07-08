import 'package:flutter/material.dart';

import '../../../services/admin_service.dart';
import '../../../theme/theme.dart';

class AgentManageScreen extends StatefulWidget {
  const AgentManageScreen({super.key});

  @override
  State<AgentManageScreen> createState() => _AgentManageScreenState();
}

class _AgentManageScreenState extends State<AgentManageScreen> {
  String _status = 'pending';

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charColor,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AdminService.fetchAgents(_status),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.goldColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final agents = snapshot.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['pending', 'approved', 'rejected']
                      .map(
                        (value) => ChoiceChip(
                          label: Text(value == 'pending' ? 'Chờ duyệt' : value == 'approved' ? 'Đã duyệt' : 'Từ chối'),
                          selected: _status == value,
                          onSelected: (_) => setState(() => _status = value),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: agents.isEmpty
                    ? const Center(child: Text('Chưa có yêu cầu', style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: agents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final agent = agents[index];
                          return Card(
                            child: ListTile(
                              title: Text(agent['full_name']?.toString() ?? agent['email']?.toString() ?? 'Khách sỉ'),
                              subtitle: Text('${agent['phone'] ?? ''}\n${agent['email'] ?? ''}'),
                              isThreeLine: true,
                              trailing: _status == 'pending'
                                  ? Wrap(
                                      children: [
                                        IconButton(
                                          onPressed: () async {
                                            await AdminService.approveAgent(agent['id'].toString());
                                            await _refresh();
                                          },
                                          icon: const Icon(Icons.check_circle_outline),
                                        ),
                                        IconButton(
                                          onPressed: () async {
                                            await AdminService.rejectAgent(agent['id'].toString(), 'Không phù hợp');
                                            await _refresh();
                                          },
                                          icon: const Icon(Icons.block_outlined),
                                        ),
                                      ],
                                    )
                                  : IconButton(
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
              ),
            ],
          );
        },
      ),
    );
  }
}
