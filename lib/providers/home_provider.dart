import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_summary.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';

class MonthSummary {
  const MonthSummary({required this.totalSpent, required this.totalSaved, required this.byDay});

  final double totalSpent;
  final double totalSaved;

  /// Keyed by day-of-month (1-based). Missing entries mean "no data yet"
  /// (future day, or nothing recomputed) and should render as an empty cell.
  final Map<int, DailySummary> byDay;
}

/// Recomputes daily_summaries from transactions, then aggregates them for the
/// given [month]. `month`'s day component is ignored.
final monthSummaryProvider = FutureProvider.family<MonthSummary, DateTime>((ref, month) async {
  final service = ref.watch(supabaseServiceProvider);
  await service.recomputeMonthSummaries(month);

  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  final summaries = await service.fetchDailySummaries(
    from: DateTime(month.year, month.month, 1),
    to: DateTime(month.year, month.month, daysInMonth),
  );

  double spent = 0;
  double saved = 0;
  final byDay = <int, DailySummary>{};
  for (final summary in summaries) {
    spent += summary.amountSpent;
    saved += summary.amountSaved;
    byDay[summary.date.day] = summary;
  }
  return MonthSummary(totalSpent: spent, totalSaved: saved, byDay: byDay);
});

/// This calendar month's food-delivery orders, newest first — backs the
/// Overview screen's total/order-count, top-service breakdown, and recent
/// orders list.
final currentMonthOrdersProvider = FutureProvider<List<TransactionModel>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(supabaseServiceProvider)
      .fetchTransactions(foodDeliveryOnly: true, since: DateTime(now.year, now.month, 1));
});
