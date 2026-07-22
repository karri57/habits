import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import 'auth_provider.dart';

final budgetProvider = FutureProvider<Budget?>(
  (ref) => ref.watch(supabaseServiceProvider).fetchBudget(),
);

/// Amount spent (food delivery only) so far in the current budget cycle.
final cycleSpentProvider = FutureProvider<double>((ref) async {
  final budget = await ref.watch(budgetProvider.future);
  if (budget == null) return 0;
  final now = DateTime.now();
  return ref
      .watch(supabaseServiceProvider)
      .sumFoodDeliverySpent(from: budget.cycleStart(now), to: now);
});
