class DailySummary {
  const DailySummary({
    required this.date,
    required this.amountSpent,
    required this.amountSaved,
  });

  final DateTime date;
  final double amountSpent;
  final double amountSaved;

  factory DailySummary.fromMap(Map<String, dynamic> map) => DailySummary(
        date: DateTime.parse(map['date'] as String),
        amountSpent: (map['amount_spent'] as num).toDouble(),
        amountSaved: (map['amount_saved'] as num).toDouble(),
      );

  /// Positive when the day was under the daily budget allocation (money saved),
  /// negative when it was overspent. `amount_saved` already stores this signed
  /// value (allocation minus spent) — see [SupabaseService.recomputeMonthSummaries].
  double get net => amountSaved;
}
