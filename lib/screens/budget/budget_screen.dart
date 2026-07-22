import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/budget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(budgetProvider);

    // Fires the 75%/100% local notification (at most once per cycle — see
    // NotificationService) whenever spend-this-cycle changes.
    ref.listen(cycleSpentProvider, (previous, next) {
      final spent = next.value;
      final budget = ref.read(budgetProvider).value;
      if (spent == null || budget == null) return;
      ref.read(notificationServiceProvider).checkBudgetThresholds(
            spent: spent,
            budgetAmount: budget.monthlyBudgetAmount,
            notify75: budget.notifyAt75,
            notify100: budget.notifyAt100,
            cycleStart: budget.cycleStart(DateTime.now()),
          );
    });

    return budgetAsync.when(
      data: (budget) => _BudgetForm(initial: budget),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Couldn\'t load budget: $err')),
    );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({required this.initial});

  final Budget? initial;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  late final TextEditingController _incomeController;
  late final TextEditingController _budgetController;
  bool _usePercent = false;
  double _percent = 7.5;
  late int _cycleStartDay;
  late bool _notify75;
  late bool _notify100;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _incomeController = TextEditingController(text: b?.monthlyIncome?.toStringAsFixed(0) ?? '');
    _budgetController = TextEditingController(text: b?.monthlyBudgetAmount.toStringAsFixed(0) ?? '');
    _cycleStartDay = b?.cycleStartDay ?? 1;
    _notify75 = b?.notifyAt75 ?? true;
    _notify100 = b?.notifyAt100 ?? true;
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  double get _income => double.tryParse(_incomeController.text) ?? 0;

  double get _budgetAmount =>
      _usePercent ? _income * _percent / 100 : (double.tryParse(_budgetController.text) ?? 0);

  Future<void> _save() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      final budget = Budget(
        id: widget.initial?.id ?? '',
        userId: userId,
        monthlyIncome: _incomeController.text.isEmpty ? null : _income,
        monthlyBudgetAmount: _budgetAmount,
        cycleStartDay: _cycleStartDay,
        notifyAt75: _notify75,
        notifyAt100: _notify100,
      );
      await ref.read(supabaseServiceProvider).upsertBudget(budget);
      ref.invalidate(budgetProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Budget saved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Couldn\'t save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycleSpentAsync = ref.watch(cycleSpentProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.initial != null)
          _ProgressCard(budget: widget.initial!, spentAsync: cycleSpentAsync),
        if (widget.initial != null) const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Monthly income', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _incomeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '\$ ', hintText: 'e.g. 5000'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Food delivery budget', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Amount')),
                  ButtonSegment(value: true, label: Text('% of income')),
                ],
                selected: {_usePercent},
                onSelectionChanged: (s) => setState(() => _usePercent = s.first),
              ),
              const SizedBox(height: 16),
              if (_usePercent) ...[
                Text(
                  '${_percent.toStringAsFixed(1)}% of income = ${formatCurrency(_budgetAmount)}/mo',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _percent,
                  min: 1,
                  max: 20,
                  divisions: 38,
                  label: '${_percent.toStringAsFixed(1)}%',
                  onChanged: (v) => setState(() => _percent = v),
                ),
                const Text(
                  'Suggested: 5-10% of monthly income',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ] else
                TextField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(prefixText: '\$ ', hintText: 'e.g. 150'),
                  onChanged: (_) => setState(() {}),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Budget cycle', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Resets on day'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _cycleStartDay,
                    dropdownColor: AppColors.surfaceElevated,
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => _cycleStartDay = v ?? 1),
                  ),
                  const Text('of each month'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications', style: TextStyle(color: AppColors.textSecondary)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert at 75% of budget'),
                value: _notify75,
                onChanged: (v) => setState(() => _notify75 = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert at 100% of budget'),
                value: _notify100,
                onChanged: (v) => setState(() => _notify100 = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save budget'),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.budget, required this.spentAsync});

  final Budget budget;
  final AsyncValue<double> spentAsync;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cycleEnd = budget.cycleEnd(now);
    final daysRemaining = cycleEnd.difference(DateTime(now.year, now.month, now.day)).inDays + 1;
    final spent = spentAsync.value ?? 0;
    final ratio = budget.monthlyBudgetAmount <= 0 ? 0.0 : (spent / budget.monthlyBudgetAmount);
    final remaining = (budget.monthlyBudgetAmount - spent).clamp(0, double.infinity);
    final safePerDay = daysRemaining > 0 ? remaining / daysRemaining : 0;
    final color = AppColors.budgetColor(ratio);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatCurrency(spent)} of ${formatCurrency(budget.monthlyBudgetAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${(ratio * 100).clamp(0, 999).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 10,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$daysRemaining days left in cycle',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('${formatCurrency(safePerDay.toDouble())}/day safe to spend',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
