import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/report_repository.dart';
import '../../../../providers/report_provider.dart';
import '../../../../theme/theme.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final NumberFormat _currency = NumberFormat('#,##0', 'vi_VN');
  final NumberFormat _decimal = NumberFormat('#,##0.#', 'vi_VN');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialReport());
  }

  Future<void> _loadInitialReport() async {
    final provider = context.read<ReportProvider>();
    if (provider.data != null || provider.isLoading) return;
    await provider.load();
    _showLoadErrorIfNeeded(provider);
  }

  Future<void> _setPreset(ReportRangePreset preset) async {
    final provider = context.read<ReportProvider>();
    await provider.setPreset(preset);
    _showLoadErrorIfNeeded(provider);
  }

  Future<void> _pickRange() async {
    final provider = context.read<ReportProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: provider.range,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.goldColor,
              onPrimary: AppTheme.charColor,
              surface: AppTheme.surfaceColor,
              onSurface: AppTheme.creamColor,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    await provider.setCustomRange(picked);
    _showLoadErrorIfNeeded(provider);
  }

  void _showLoadErrorIfNeeded(ReportProvider provider) {
    if (!mounted || provider.errorMessage == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage!),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
  }

  Future<void> _exportPdf(ReportProvider provider) async {
    final data = provider.data;
    if (data == null) return;
    try {
      final bytes = await _buildPdf(data, provider.range);
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'bao-cao-doanh-thu-${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không xuất được PDF. Vui lòng thử lại.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<Uint8List> _buildPdf(ReportData data, DateTimeRange range) async {
    final doc = pw.Document();
    final rangeText =
        '${DateFormat('dd/MM/yyyy', 'vi_VN').format(range.start)} - ${DateFormat('dd/MM/yyyy', 'vi_VN').format(range.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Ca Phe Hai Tin',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Bao cao doanh thu: $rangeText',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const ['Chi so', 'Gia tri'],
            data: [
              ['Tong doanh thu', _money(data.summary.totalRevenue)],
              ['Tong don', '${data.summary.totalOrders}'],
              ['Don da giao', '${data.summary.deliveredOrders}'],
              ['Don da huy', '${data.summary.cancelledOrders}'],
              [
                'Ty le thanh cong',
                '${data.summary.successRate.toStringAsFixed(1)}%',
              ],
              ['Trung binh moi don', _money(data.summary.avgOrderValue)],
              ['Doanh thu khach si', _money(data.summary.wholesaleRevenue)],
              ['Doanh thu khach le', _money(data.summary.retailRevenue)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Top san pham ban chay',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'San pham', 'So luong', 'Doanh thu'],
            data: [
              for (var i = 0; i < data.topProducts.length; i++)
                [
                  '${i + 1}',
                  data.topProducts[i].productName,
                  _quantityLabel(data.topProducts[i]),
                  _money(data.topProducts[i].totalRevenue),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final data = provider.data;
        return Column(
          children: [
            _DateFilterBar(
              provider: provider,
              onPresetSelected: _setPreset,
              onCustomSelected: _pickRange,
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.goldColor,
                onRefresh: () async {
                  await provider.load();
                  _showLoadErrorIfNeeded(provider);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: provider.isLoading && data == null
                      ? const _ReportSkeleton()
                      : _ReportContent(
                          key: ValueKey(provider.rangeLabel),
                          data: data ?? ReportData.empty,
                          isRefreshing: provider.isLoading,
                          errorMessage: provider.errorMessage,
                          money: _money,
                          shortMoney: _shortMoney,
                          percent: _percent,
                          quantityLabel: _quantityLabel,
                          onExportPdf: () => _exportPdf(provider),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _money(int value) => '${_currency.format(value)}đ';

  String _shortMoney(num value) {
    final amount = value.abs();
    if (amount >= 1000000000) {
      return '${_decimal.format(value / 1000000000)}tỷ';
    }
    if (amount >= 1000000) {
      return '${_decimal.format(value / 1000000)}tr';
    }
    if (amount >= 1000) {
      return '${_decimal.format(value / 1000)}k';
    }
    return _decimal.format(value);
  }

  String _percent(int value, int total) {
    if (total <= 0) return '0%';
    return '${(value / total * 100).toStringAsFixed(1)}%';
  }

  String _quantityLabel(TopProduct product) {
    if (product.totalKg > 0) {
      return '${_decimal.format(product.totalKg)} kg';
    }
    return '${product.totalQuantity} sp';
  }
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({
    required this.provider,
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final ReportProvider provider;
  final ValueChanged<ReportRangePreset> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.charColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.lineColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Báo cáo doanh thu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.lightTextColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (provider.isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.goldColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              provider.rangeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTextColor.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _RangeChip(
                    label: 'Hôm nay',
                    selected: provider.preset == ReportRangePreset.today,
                    onTap: () => onPresetSelected(ReportRangePreset.today),
                  ),
                  _RangeChip(
                    label: '7 ngày',
                    selected: provider.preset == ReportRangePreset.sevenDays,
                    onTap: () => onPresetSelected(ReportRangePreset.sevenDays),
                  ),
                  _RangeChip(
                    label: '30 ngày',
                    selected: provider.preset == ReportRangePreset.thirtyDays,
                    onTap: () => onPresetSelected(ReportRangePreset.thirtyDays),
                  ),
                  _RangeChip(
                    label: '3 tháng',
                    selected: provider.preset == ReportRangePreset.threeMonths,
                    onTap: () =>
                        onPresetSelected(ReportRangePreset.threeMonths),
                  ),
                  _RangeChip(
                    label: 'Tùy chọn',
                    icon: Icons.date_range_rounded,
                    selected: provider.preset == ReportRangePreset.custom,
                    onTap: onCustomSelected,
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

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 16,
                color: selected ? AppTheme.charColor : AppTheme.goldColor,
              ),
        label: Text(label),
        selectedColor: AppTheme.goldColor,
        backgroundColor: AppTheme.surfaceColor,
        labelStyle: TextStyle(
          color: selected ? AppTheme.charColor : AppTheme.creamColor,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppTheme.goldColor : AppTheme.lineColor,
          ),
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    super.key,
    required this.data,
    required this.isRefreshing,
    required this.errorMessage,
    required this.money,
    required this.shortMoney,
    required this.percent,
    required this.quantityLabel,
    required this.onExportPdf,
  });

  final ReportData data;
  final bool isRefreshing;
  final String? errorMessage;
  final String Function(int value) money;
  final String Function(num value) shortMoney;
  final String Function(int value, int total) percent;
  final String Function(TopProduct product) quantityLabel;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (errorMessage != null) ...[
          _ErrorBanner(message: errorMessage!),
          const SizedBox(height: 12),
        ],
        if (isRefreshing) const LinearProgressIndicator(minHeight: 2),
        if (isRefreshing) const SizedBox(height: 12),
        _SummaryGrid(data: data, money: money),
        const SizedBox(height: 18),
        _RevenueBarChart(
          data: data.revenueByDay,
          money: money,
          shortMoney: shortMoney,
        ),
        const SizedBox(height: 18),
        _WholesaleRetailSection(
          data: data.summary,
          money: money,
          percent: percent,
        ),
        const SizedBox(height: 18),
        _PieReportSection(
          title: 'Doanh thu theo danh mục',
          values: data.revenueByCategory,
          money: money,
          percent: percent,
          colors: const [
            AppTheme.goldColor,
            AppTheme.emberColor,
            AppTheme.successColor,
            AppTheme.warningColor,
            AppTheme.dangerColor,
            Color(0xFF8EC5A5),
          ],
        ),
        const SizedBox(height: 18),
        _PieReportSection(
          title: 'Doanh thu theo thanh toán',
          values: data.revenueByPaymentMethod,
          money: money,
          percent: percent,
          colors: const [
            Color(0xFFE5B15A),
            Color(0xFFF28A2E),
            Color(0xFF73C08D),
            Color(0xFFDE6A59),
            Color(0xFF9B82D9),
          ],
        ),
        const SizedBox(height: 18),
        _TopProductsSection(
          products: data.topProducts,
          money: money,
          quantityLabel: quantityLabel,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onExportPdf,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Xuất PDF'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data, required this.money});

  final ReportData data;
  final String Function(int value) money;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.75,
      children: [
        _MetricCard(
          icon: Icons.payments_outlined,
          title: 'Doanh thu',
          value: money(summary.totalRevenue),
          detail: 'Từ đơn đã giao',
          color: AppTheme.goldColor,
        ),
        _MetricCard(
          icon: Icons.inventory_2_outlined,
          title: 'Tổng đơn',
          value: '${summary.totalOrders}',
          detail:
              '${summary.deliveredOrders} thành công • ${summary.cancelledOrders} đã hủy',
          color: AppTheme.emberColor,
        ),
        _MetricCard(
          icon: Icons.query_stats_rounded,
          title: 'Tỷ lệ thành công',
          value: '${summary.successRate.toStringAsFixed(1)}%',
          detail: '${summary.pendingOrders} đơn đang xử lý',
          color: AppTheme.successColor,
        ),
        _MetricCard(
          icon: Icons.diamond_outlined,
          title: 'TB/đơn',
          value: money(summary.avgOrderValue),
          detail: 'Giá trị trung bình',
          color: AppTheme.warningColor,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.mutedColor,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.creamColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({
    required this.data,
    required this.money,
    required this.shortMoney,
  });

  final List<RevenueByDay> data;
  final String Function(int value) money;
  final String Function(num value) shortMoney;

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((item) => item.revenue > 0);
    final maxRevenue = data.fold<int>(
      0,
      (current, item) => math.max(current, item.revenue),
    );
    final titleInterval = math.max(1, (data.length / 6).ceil());

    return _Section(
      title: 'Doanh thu theo ngày',
      child: SizedBox(
        height: 280,
        child: hasData
            ? BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: math.max(1, maxRevenue * 1.25).toDouble(),
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: AppTheme.lineColor,
                      strokeWidth: 0.6,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = data[group.x.toInt()];
                        return BarTooltipItem(
                          '${DateFormat('dd/MM/yyyy').format(item.day)}\n'
                          '${money(item.revenue)}\n'
                          '${item.orderCount} đơn',
                          const TextStyle(
                            color: AppTheme.charColor,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            shortMoney(value),
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          final isVisible =
                              index == data.length - 1 ||
                              index % titleInterval == 0;
                          if (!isVisible) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('dd/MM').format(data[index].day),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data[i].revenue.toDouble(),
                            width: data.length > 18 ? 10 : 16,
                            borderRadius: BorderRadius.circular(6),
                            gradient: AppTheme.flameGradient,
                          ),
                        ],
                      ),
                  ],
                ),
              )
            : const _EmptyState(
                icon: Icons.bar_chart_rounded,
                text: 'Chưa có dữ liệu trong khoảng thời gian này',
              ),
      ),
    );
  }
}

class _WholesaleRetailSection extends StatelessWidget {
  const _WholesaleRetailSection({
    required this.data,
    required this.money,
    required this.percent,
  });

  final ReportSummary data;
  final String Function(int value) money;
  final String Function(int value, int total) percent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = data.wholesaleRevenue + data.retailRevenue;
        final wholesale = _SplitRevenueCard(
          icon: Icons.storefront_rounded,
          label: 'Khách sỉ',
          amount: money(data.wholesaleRevenue),
          ratio: percent(data.wholesaleRevenue, total),
          color: AppTheme.goldColor,
        );
        final retail = _SplitRevenueCard(
          icon: Icons.person_outline_rounded,
          label: 'Khách lẻ',
          amount: money(data.retailRevenue),
          ratio: percent(data.retailRevenue, total),
          color: AppTheme.emberColor,
        );
        if (constraints.maxWidth < 520) {
          return Column(
            children: [wholesale, const SizedBox(height: 10), retail],
          );
        }
        return Row(
          children: [
            Expanded(child: wholesale),
            const SizedBox(width: 10),
            Expanded(child: retail),
          ],
        );
      },
    );
  }
}

class _SplitRevenueCard extends StatelessWidget {
  const _SplitRevenueCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.ratio,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String amount;
  final String ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.goldColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(ratio, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieReportSection extends StatelessWidget {
  const _PieReportSection({
    required this.title,
    required this.values,
    required this.money,
    required this.percent,
    required this.colors,
  });

  final String title;
  final Map<String, int> values;
  final String Function(int value) money;
  final String Function(int value, int total) percent;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = values.values.fold<int>(0, (sum, value) => sum + value);
    return _Section(
      title: title,
      child: SizedBox(
        height: total == 0 ? 180 : null,
        child: total == 0
            ? const _EmptyState(
                icon: Icons.pie_chart_outline_rounded,
                text: 'Chưa có dữ liệu trong khoảng thời gian này',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final entries = values.entries.toList();
                  final chart = SizedBox(
                    width: 220,
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 44,
                        sections: [
                          for (var i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              color: colors[i % colors.length],
                              value: entries[i].value.toDouble(),
                              title: percent(entries[i].value, total),
                              radius: 72,
                              titleStyle: const TextStyle(
                                color: AppTheme.charColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  final legend = Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        _LegendRow(
                          color: colors[i % colors.length],
                          label: entries[i].key,
                          detail:
                              '${percent(entries[i].value, total)} • ${money(entries[i].value)}',
                        ),
                    ],
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      children: [
                        Center(child: chart),
                        const SizedBox(height: 12),
                        legend,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      chart,
                      const SizedBox(width: 14),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.detail,
  });

  final Color color;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection({
    required this.products,
    required this.money,
    required this.quantityLabel,
  });

  final List<TopProduct> products;
  final String Function(int value) money;
  final String Function(TopProduct product) quantityLabel;

  @override
  Widget build(BuildContext context) {
    final maxQuantity = products.fold<int>(
      0,
      (current, item) => math.max(current, item.totalQuantity),
    );
    return _Section(
      title: 'Top 10 sản phẩm bán chạy',
      child: products.isEmpty
          ? const SizedBox(
              height: 180,
              child: _EmptyState(
                icon: Icons.emoji_events_outlined,
                text: 'Chưa có dữ liệu sản phẩm trong khoảng thời gian này',
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < products.length; i++)
                  _TopProductTile(
                    rank: i + 1,
                    product: products[i],
                    maxQuantity: maxQuantity,
                    money: money,
                    quantityLabel: quantityLabel,
                  ),
              ],
            ),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({
    required this.rank,
    required this.product,
    required this.maxQuantity,
    required this.money,
    required this.quantityLabel,
  });

  final int rank;
  final TopProduct product;
  final int maxQuantity;
  final String Function(int value) money;
  final String Function(TopProduct product) quantityLabel;

  @override
  Widget build(BuildContext context) {
    final ratio = maxQuantity <= 0 ? 0.0 : product.totalQuantity / maxQuantity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '#$rank',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.goldColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                quantityLabel(product),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 10),
              Text(
                money(product.totalRevenue),
                style: const TextStyle(
                  color: AppTheme.goldColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 9,
              backgroundColor: AppTheme.surfaceRaisedColor,
              valueColor: const AlwaysStoppedAnimation(AppTheme.emberColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.mutedColor, size: 42),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.dangerColor),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.75,
          children: const [
            _SkeletonBox(),
            _SkeletonBox(),
            _SkeletonBox(),
            _SkeletonBox(),
          ],
        ),
        const SizedBox(height: 18),
        const _SkeletonBox(height: 300),
        const SizedBox(height: 18),
        const _SkeletonBox(height: 160),
        const SizedBox(height: 18),
        const _SkeletonBox(height: 260),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineColor),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.goldColor,
          ),
        ),
      ),
    );
  }
}
