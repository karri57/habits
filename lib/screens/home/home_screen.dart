import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/budget.dart';
import '../../models/platform.dart';
import '../../models/transaction.dart';
import '../../providers/budget_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final ordersAsync = ref.watch(currentMonthOrdersProvider);
    final budgetAsync = ref.watch(budgetProvider);
    final now = DateTime.now();
    final monthSummaryAsync = ref.watch(monthSummaryProvider(DateTime(now.year, now.month)));
    final prevMonthSummaryAsync =
        ref.watch(monthSummaryProvider(DateTime(now.year, now.month - 1)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentMonthOrdersProvider);
        ref.invalidate(monthSummaryProvider(DateTime(now.year, now.month)));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hello, ${profileAsync.value?.firstName ?? 'there'} 👋',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No new notifications')),
                ),
              ),
            ],
          ),
          ordersAsync.when(
            data: (orders) {
              final totalSpent = orders.fold(0.0, (sum, o) => sum + o.amount);
              final byPlatform = <DeliveryPlatform, double>{};
              for (final o in orders) {
                final p = o.platform ?? DeliveryPlatform.other;
                byPlatform[p] = (byPlatform[p] ?? 0) + o.amount;
              }
              final topEntry = byPlatform.entries.isEmpty
                  ? null
                  : byPlatform.entries.reduce((a, b) => a.value > b.value ? a : b);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "This month you've spent",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(totalSpent),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Across ${orders.length} order${orders.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (topEntry != null)
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Top service', style: TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Text(
                                  topEntry.key.label,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  formatCurrency(topEntry.value),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${(topEntry.value / totalSpent * 100).toStringAsFixed(0)}% of spend',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 84,
                            width: 84,
                            child: _ServiceDonut(byPlatform: byPlatform, total: totalSpent),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text('Recent orders', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (orders.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No orders yet this month.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          for (final order in orders.take(3)) _OrderRow(order: order),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('Couldn\'t load orders: $err'),
            ),
          ),
          const SizedBox(height: 16),
          budgetAsync.when(
            data: (budget) => budget == null
                ? AppCard(
                    onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 3,
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.accentBlue),
                        SizedBox(width: 12),
                        Expanded(child: Text('Set up your monthly budget to start tracking goals')),
                        Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  )
                : _BudgetCard(budget: budget, ordersAsync: ordersAsync),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _InsightsCard(current: monthSummaryAsync, previous: prevMonthSummaryAsync),
        ],
      ),
    );
  }
}

class _ServiceDonut extends StatelessWidget {
  const _ServiceDonut({required this.byPlatform, required this.total});

  final Map<DeliveryPlatform, double> byPlatform;
  final double total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 20,
        sections: [
          for (final entry in byPlatform.entries)
            PieChartSectionData(
              value: entry.value,
              color: entry.key.color,
              showTitle: false,
              radius: 18,
            ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final TransactionModel order;

  @override
  Widget build(BuildContext context) {
    final platform = order.platform;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (platform?.color ?? AppColors.textMuted).withValues(alpha: 0.15),
        child: Icon(platform?.icon ?? Icons.receipt_long, color: platform?.color ?? AppColors.textMuted, size: 20),
      ),
      title: Text(platform?.label ?? order.merchantName),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(formatCurrency(order.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            DateFormat.MMMd().format(order.date),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.ordersAsync});

  final Budget budget;
  final AsyncValue<List<TransactionModel>> ordersAsync;

  @override
  Widget build(BuildContext context) {
    final spent = ordersAsync.value?.fold(0.0, (sum, o) => sum + o.amount) ?? 0;
    final amount = budget.monthlyBudgetAmount;
    final ratio = amount <= 0 ? 0.0 : (spent / amount).clamp(0, 1).toDouble();
    final color = AppColors.budgetColor(amount <= 0 ? 0 : spent / amount);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly budget', style: TextStyle(color: AppColors.textSecondary)),
              Text('Spent', style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatCurrency(amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(formatCurrency(spent), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.current, required this.previous});

  final AsyncValue<MonthSummary> current;
  final AsyncValue<MonthSummary> previous;

  @override
  Widget build(BuildContext context) {
    final currentData = current.value;
    final previousData = previous.value;
    if (currentData == null) return const SizedBox.shrink();

    final currentSpent = currentData.byDay.values.fold(0.0, (sum, d) => sum + d.amountSpent);
    final previousSpent = previousData?.byDay.values.fold(0.0, (sum, d) => sum + d.amountSpent) ?? 0;
    final diff = previousSpent - currentSpent;
    final better = diff >= 0;

    final points = currentData.byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      const TextSpan(text: 'You spent '),
                      TextSpan(
                        text: '${formatCurrency(diff.abs())} ${better ? 'less' : 'more'}',
                        style: TextStyle(
                          color: better ? AppColors.green : AppColors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' than last month'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (points.length >= 2)
            SizedBox(
              height: 40,
              width: 80,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].value.amountSpent),
                      ],
                      isCurved: true,
                      color: AppColors.green,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
