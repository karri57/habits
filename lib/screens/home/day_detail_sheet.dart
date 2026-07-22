import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/platform.dart';
import '../../models/transaction.dart';
import '../../providers/home_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';

/// Bottom sheet shown when a calendar day is tapped: that day's orders plus
/// the day's saved/overspent total.
class DayDetailSheet extends ConsumerWidget {
  const DayDetailSheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dayTransactionsProvider(day));
    final summaryAsync = ref.watch(monthSummaryProvider(DateTime(day.year, day.month)));
    final net = summaryAsync.value?.byDay[day.day]?.net;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMMd().format(day),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (net != null)
                  Text(
                    '${net >= 0 ? '+' : '-'}${formatCurrency(net.abs())}',
                    style: TextStyle(
                      color: net >= 0 ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No orders this day.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) => _OrderRow(transaction: transactions[index]),
                );
              },
              loading: () =>
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, _) => Text('Couldn\'t load orders: $err'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final platform = transaction.platform;
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: (platform?.color ?? AppColors.textMuted).withValues(alpha: 0.15),
          child: Icon(platform?.icon ?? Icons.receipt_long, color: platform?.color ?? AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(transaction.merchantName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${platform?.label ?? 'Other'} · ${DateFormat.jm().format(transaction.createdAt.toLocal())}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(formatCurrency(transaction.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
