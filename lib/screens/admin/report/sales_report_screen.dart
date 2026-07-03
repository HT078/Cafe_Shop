import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../services/admin_service.dart';
import '../../../../theme/theme.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  late DateTime _start;
  late DateTime _end;
  String _rangeLabel = 'Hôm nay';
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _setPreset('today');
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    if (preset == 'today') {
      _start = DateTime(now.year, now.month, now.day);
      _end = _start.add(const Duration(days: 1));
      _rangeLabel = 'Hôm nay';
    } else if (preset == '7days') {
      _end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _start = _end.subtract(const Duration(days: 7));
      _rangeLabel = '7 ngày';
    } else if (preset == 'month') {
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month + 1, 1);
      _rangeLabel = 'Tháng này';
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _start, end: _end.subtract(const Duration(days: 1))),
    );
    if (picked == null) return;
    setState(() {
      _start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _end = DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1));
      _rangeLabel = 'Tùy chọn';
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SalesReportData>(
      future: AdminService.salesReport(_start, _end),
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

        final data = snapshot.data ?? const SalesReportData(
          totalKg: 0,
          totalRevenue: 0,
          revenueByDay: {},
          topProducts: [],
        );

        final entries = data.revenueByDay.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        return RefreshIndicator(
          color: AppTheme.goldColor,
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Báo cáo doanh số',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'custom') {
                        _pickRange();
                      } else {
                        setState(() => _setPreset(value));
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'today', child: Text('Hôm nay')),
                      PopupMenuItem(value: '7days', child: Text('7 ngày')),
                      PopupMenuItem(value: 'month', child: Text('Tháng này')),
                      PopupMenuItem(value: 'custom', child: Text('Tùy chọn khoảng ngày')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.lineColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_rangeLabel),
                          const SizedBox(width: 6),
                          const Icon(Icons.expand_more_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatCard(
                title: 'Tổng doanh thu',
                value: '${_currency.format(data.totalRevenue)}đ',
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Tổng kg cà phê',
                value: data.totalKg.toStringAsFixed(2),
                icon: Icons.scale_outlined,
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Đơn vị tính',
                value: 'Chỉ đơn đã giao',
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: 20),
              Text(
                'Doanh thu theo ngày',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              'Chưa có dữ liệu',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.mutedColor,
                                  ),
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _maxRevenue(entries).toDouble() * 1.2,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= entries.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final day = entries[index].key;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          DateFormat('dd/MM').format(day),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                for (var i = 0; i < entries.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entries[i].value.toDouble(),
                                        width: 18,
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: AppTheme.flameGradient,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Top 5 sản phẩm bán chạy',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              if (data.topProducts.isEmpty)
                Text(
                  'Chưa có dữ liệu sản phẩm',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedColor,
                      ),
                )
              else
                ...data.topProducts.map(
                  (product) => Card(
                    child: ListTile(
                      title: Text(product['name']?.toString() ?? 'Sản phẩm'),
                      subtitle: Text('SL: ${product['quantity'] ?? 0}'),
                      trailing: Text(
                        '${_currency.format(product['revenue'] ?? 0)}đ',
                        style: const TextStyle(
                          color: AppTheme.goldColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _maxRevenue(List<MapEntry<DateTime, int>> entries) {
    if (entries.isEmpty) return 1;
    return entries
        .map((entry) => entry.value)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 31)
        .toInt();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.flameGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.charColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.goldColor,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
