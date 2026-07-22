import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/daily_summary.dart';
import '../../providers/budget_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import 'day_detail_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  DateTime get _previousMonth => DateTime(_focusedMonth.year, _focusedMonth.month - 1);

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final budgetAsync = ref.watch(budgetProvider);
    final currentSummaryAsync = ref.watch(monthSummaryProvider(_focusedMonth));
    final previousSummaryAsync = ref.watch(monthSummaryProvider(_previousMonth));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monthSummaryProvider(_focusedMonth));
        ref.invalidate(monthSummaryProvider(_previousMonth));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${timeOfDayGreeting(DateTime.now())}, '
            '${profileAsync.value?.firstName ?? 'there'}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (budgetAsync.hasValue && budgetAsync.value == null) ...[
            const SizedBox(height: 16),
            AppCard(
              onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 4,
              child: const Row(
                children: [
                  Icon(Icons.pie_chart_outline, color: AppColors.accentBlue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set up your monthly delivery budget to start tracking savings',
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Saved this month',
                  value: currentSummaryAsync.value?.totalSaved ?? 0,
                  previousValue: previousSummaryAsync.value?.totalSaved ?? 0,
                  positiveIsGood: true,
                  loading: currentSummaryAsync.isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Spent on delivery',
                  value: currentSummaryAsync.value?.totalSpent ?? 0,
                  previousValue: previousSummaryAsync.value?.totalSpent ?? 0,
                  positiveIsGood: false,
                  overBudget: budgetAsync.value != null &&
                      (currentSummaryAsync.value?.totalSpent ?? 0) >
                          budgetAsync.value!.monthlyBudgetAmount,
                  loading: currentSummaryAsync.isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: currentSummaryAsync.when(
              data: (summary) => _CalendarSection(
                focusedMonth: _focusedMonth,
                byDay: summary.byDay,
                onMonthChanged: (month) => setState(
                  () => _focusedMonth = DateTime(month.year, month.month),
                ),
                onDayTapped: (day) => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DayDetailSheet(day: day),
                ),
              ),
              loading: () => const SizedBox(
                height: 360,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SizedBox(
                height: 360,
                child: Center(child: Text('Couldn\'t load calendar: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.previousValue,
    required this.positiveIsGood,
    this.overBudget = false,
    required this.loading,
  });

  final String label;
  final double value;
  final double previousValue;
  final bool positiveIsGood;
  final bool overBudget;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final good = positiveIsGood ? value >= 0 : !overBudget;
    final valueColor = good ? AppColors.green : AppColors.red;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          if (loading)
            const SizedBox(
              height: 28,
              child: LinearProgressIndicator(),
            )
          else
            Text(
              formatCurrencyWhole(value),
              style: TextStyle(
                color: valueColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${formatPercentChange(value, previousValue)} vs last month',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.focusedMonth,
    required this.byDay,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  final DateTime focusedMonth;
  final Map<int, DailySummary> byDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTapped;

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: focusedMonth,
      currentDay: DateTime.now(),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      daysOfWeekHeight: 24,
      rowHeight: 56,
      sixWeekMonthsEnforced: false,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        weekendStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      calendarStyle: const CalendarStyle(outsideDaysVisible: false),
      onPageChanged: onMonthChanged,
      onDaySelected: (selected, _) => onDayTapped(selected),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) => _DayCell(day: day, summary: byDay[day.day]),
        todayBuilder: (context, day, _) =>
            _DayCell(day: day, summary: byDay[day.day], isToday: true),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, this.summary, this.isToday = false});

  final DateTime day;
  final DailySummary? summary;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final net = summary?.net;
    Color amountColor = AppColors.textMuted;
    String amountText = '';
    if (net != null) {
      amountColor = net >= 0 ? AppColors.green : AppColors.red;
      amountText = '${net >= 0 ? '+' : '-'}\$${net.abs().toStringAsFixed(0)}';
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: isToday ? Border.all(color: AppColors.accentBlue) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${day.day}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 2),
          Text(amountText, style: TextStyle(color: amountColor, fontSize: 10)),
        ],
      ),
    );
  }
}
