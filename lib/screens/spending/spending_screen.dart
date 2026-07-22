import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/platform.dart';
import '../../providers/spending_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(spendingRangeProvider);
    final dataAsync = ref.watch(spendingDataProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<SpendingRange>(
          segments: [
            for (final r in SpendingRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {range},
          showSelectedIcon: false,
          onSelectionChanged: (s) => ref.read(spendingRangeProvider.notifier).state = s.first,
        ),
        const SizedBox(height: 16),
        dataAsync.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: SizedBox(
                  height: 220,
                  child: data.chartPoints.isEmpty
                      ? const Center(
                          child: Text(
                            'No delivery spend in this period.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _SpendChart(points: data.chartPoints),
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        label: 'Avg. order size',
                        value: formatCurrency(data.averageOrderSize),
                      ),
                    ),
                    Expanded(
                      child: _StatColumn(
                        label: 'Orders / week',
                        value: data
                            .ordersPerWeek(range.startDate(DateTime.now()), DateTime.now())
                            .toStringAsFixed(1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'By platform',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    for (final platform in DeliveryPlatform.values)
                      if (data.byPlatform[platform] != null)
                        _PlatformRow(
                          platform: platform,
                          amount: data.byPlatform[platform]!,
                          total: data.totalSpent,
                        ),
                    if (data.byPlatform.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No breakdown yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(child: Text('Couldn\'t load spending: $err')),
          ),
        ),
      ],
    );
  }
}

class _SpendChart extends StatelessWidget {
  const _SpendChart({required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].amount),
    ];
    final maxY = points.map((p) => p.amount).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (points.length / 4).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(points[i].date),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      formatCurrency(s.y),
                      const TextStyle(color: AppColors.textPrimary),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accentBlue,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentBlue.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({required this.platform, required this.amount, required this.total});

  final DeliveryPlatform platform;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0 : (amount / total) * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: platform.color.withValues(alpha: 0.15),
            child: Icon(platform.icon, color: platform.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(platform.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('${pct.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          Text(formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
