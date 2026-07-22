import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/platform.dart';
import '../../models/transaction.dart';
import '../../providers/transactions_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import 'add_transaction_sheet.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodOnly = ref.watch(transactionsFoodDeliveryOnlyProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const AddTransactionSheet(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search merchant',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(transactionsSearchProvider.notifier).state = v,
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('All Transactions')),
                ButtonSegment(value: true, label: Text('Food Delivery Only')),
              ],
              selected: {foodOnly},
              onSelectionChanged: (s) =>
                  ref.read(transactionsFoodDeliveryOnlyProvider.notifier).state = s.first,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const Center(
                      child: Text(
                        'No transactions yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) => _TransactionRow(transaction: transactions[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Couldn\'t load transactions: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final platform = transaction.platform;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: transaction)),
      ),
      leading: CircleAvatar(
        backgroundColor: (platform?.color ?? AppColors.textMuted).withValues(alpha: 0.15),
        child: platform != null
            ? Icon(platform.icon, color: platform.color)
            : Text(
                transaction.merchantName.isNotEmpty
                    ? transaction.merchantName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
              ),
      ),
      title: Text(transaction.merchantName),
      subtitle: Row(
        children: [
          Text(DateFormat.yMMMd().format(transaction.date)),
          if (transaction.isFoodDelivery && platform != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: platform.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                platform.label,
                style: TextStyle(color: platform.color, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        formatCurrency(transaction.amount),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
