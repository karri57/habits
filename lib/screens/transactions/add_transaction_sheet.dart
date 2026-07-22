import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/platform.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../theme/app_colors.dart';

/// "+ Add transaction" flow for orders Plaid didn't catch (e.g. paid via gift
/// card): amount, platform, date, notes.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DeliveryPlatform _platform = DeliveryPlatform.doordash;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(supabaseServiceProvider).addTransaction(TransactionModel(
            id: '',
            userId: userId,
            merchantName: _platform.label,
            amount: amount,
            date: _date,
            platform: _platform,
            isFoodDelivery: true,
            source: TransactionSource.manual,
            note: _noteController.text.isEmpty ? null : _noteController.text,
            createdAt: DateTime.now(),
          ));
      ref.invalidate(transactionsProvider);
      ref.invalidate(monthSummaryProvider(DateTime(_date.year, _date.month)));
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add transaction',
              style:
                  Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeliveryPlatform>(
              initialValue: _platform,
              dropdownColor: AppColors.surfaceElevated,
              decoration: const InputDecoration(labelText: 'Platform'),
              items: [
                for (final p in DeliveryPlatform.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (v) => setState(() => _platform = v ?? _platform),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(DateFormat.yMMMd().format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
