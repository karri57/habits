import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/platform.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';

enum SpendingRange { oneMonth, threeMonths, sixMonths, ytd, oneYear, all }

extension SpendingRangeX on SpendingRange {
  String get label {
    switch (this) {
      case SpendingRange.oneMonth:
        return '1M';
      case SpendingRange.threeMonths:
        return '3M';
      case SpendingRange.sixMonths:
        return '6M';
      case SpendingRange.ytd:
        return 'YTD';
      case SpendingRange.oneYear:
        return '1Y';
      case SpendingRange.all:
        return 'All';
    }
  }

  DateTime startDate(DateTime now) {
    switch (this) {
      case SpendingRange.oneMonth:
        return DateTime(now.year, now.month - 1, now.day);
      case SpendingRange.threeMonths:
        return DateTime(now.year, now.month - 3, now.day);
      case SpendingRange.sixMonths:
        return DateTime(now.year, now.month - 6, now.day);
      case SpendingRange.ytd:
        return DateTime(now.year, 1, 1);
      case SpendingRange.oneYear:
        return DateTime(now.year - 1, now.month, now.day);
      case SpendingRange.all:
        return DateTime(2000, 1, 1);
    }
  }
}

class ChartPoint {
  const ChartPoint(this.date, this.amount);
  final DateTime date;
  final double amount;
}

class SpendingData {
  const SpendingData({
    required this.transactions,
    required this.byPlatform,
    required this.chartPoints,
  });

  final List<TransactionModel> transactions;
  final Map<DeliveryPlatform, double> byPlatform;
  final List<ChartPoint> chartPoints;

  double get totalSpent => byPlatform.values.fold(0, (a, b) => a + b);

  double get averageOrderSize =>
      transactions.isEmpty ? 0 : totalSpent / transactions.length;

  double ordersPerWeek(DateTime from, DateTime to) {
    final days = to.difference(from).inDays.clamp(1, 1 << 30);
    final weeks = days / 7;
    return weeks <= 0 ? 0 : transactions.length / weeks;
  }
}

final spendingRangeProvider = StateProvider<SpendingRange>((ref) => SpendingRange.oneMonth);

final spendingDataProvider = FutureProvider<SpendingData>((ref) async {
  final range = ref.watch(spendingRangeProvider);
  final now = DateTime.now();
  final from = range.startDate(now);
  final transactions = await ref
      .watch(supabaseServiceProvider)
      .fetchTransactions(foodDeliveryOnly: true, since: from);

  final byPlatform = <DeliveryPlatform, double>{};
  final byDay = <DateTime, double>{};
  for (final t in transactions) {
    final platform = t.platform ?? DeliveryPlatform.other;
    byPlatform[platform] = (byPlatform[platform] ?? 0) + t.amount;
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    byDay[day] = (byDay[day] ?? 0) + t.amount;
  }
  final sortedDays = byDay.keys.toList()..sort();
  final chartPoints = [for (final d in sortedDays) ChartPoint(d, byDay[d]!)];

  return SpendingData(transactions: transactions, byPlatform: byPlatform, chartPoints: chartPoints);
});
