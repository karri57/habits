import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/platform.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  late final TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(supabaseServiceProvider)
          .updateTransactionNote(widget.transaction.id, _noteController.text);
      ref.invalidate(transactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(t.amount),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(t.merchantName, style: const TextStyle(color: AppColors.textSecondary)),
                const Divider(height: 32),
                _DetailRow(label: 'Date', value: DateFormat.yMMMd().format(t.date)),
                _DetailRow(
                  label: 'Category',
                  value: t.isFoodDelivery ? 'Food Delivery' : 'Uncategorized',
                ),
                if (t.platform != null)
                  _DetailRow(label: 'Platform', value: t.platform!.label),
                _DetailRow(
                  label: 'Account',
                  value: t.accountId == null ? 'Manual entry' : 'Linked account',
                ),
                _DetailRow(
                  label: 'Source',
                  value: t.source == TransactionSource.manual ? 'Manual' : 'Plaid',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Add a note'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving ? null : _saveNote,
                    child: _saving ? const Text('Saving...') : const Text('Save note'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
