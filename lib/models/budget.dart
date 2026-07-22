class Budget {
  const Budget({
    required this.id,
    required this.userId,
    this.monthlyIncome,
    required this.monthlyBudgetAmount,
    required this.cycleStartDay,
    required this.notifyAt75,
    required this.notifyAt100,
  });

  final String id;
  final String userId;
  final double? monthlyIncome;
  final double monthlyBudgetAmount;
  final int cycleStartDay;
  final bool notifyAt75;
  final bool notifyAt100;

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        monthlyIncome: (map['monthly_income'] as num?)?.toDouble(),
        monthlyBudgetAmount: (map['monthly_budget_amount'] as num).toDouble(),
        cycleStartDay: map['cycle_start_day'] as int,
        notifyAt75: map['notify_at_75'] as bool,
        notifyAt100: map['notify_at_100'] as bool,
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'monthly_income': monthlyIncome,
        'monthly_budget_amount': monthlyBudgetAmount,
        'cycle_start_day': cycleStartDay,
        'notify_at_75': notifyAt75,
        'notify_at_100': notifyAt100,
      };

  Budget copyWith({
    double? monthlyIncome,
    double? monthlyBudgetAmount,
    int? cycleStartDay,
    bool? notifyAt75,
    bool? notifyAt100,
  }) =>
      Budget(
        id: id,
        userId: userId,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        monthlyBudgetAmount: monthlyBudgetAmount ?? this.monthlyBudgetAmount,
        cycleStartDay: cycleStartDay ?? this.cycleStartDay,
        notifyAt75: notifyAt75 ?? this.notifyAt75,
        notifyAt100: notifyAt100 ?? this.notifyAt100,
      );

  /// The most recent cycle start date on or before [today].
  DateTime cycleStart(DateTime today) {
    final day = cycleStartDay.clamp(1, 28);
    final thisMonthStart = DateTime(today.year, today.month, day);
    if (!today.isBefore(thisMonthStart)) return thisMonthStart;
    final prevMonth = DateTime(today.year, today.month - 1, day);
    return prevMonth;
  }

  DateTime cycleEnd(DateTime today) {
    final start = cycleStart(today);
    return DateTime(start.year, start.month + 1, start.day).subtract(const Duration(days: 1));
  }
}
