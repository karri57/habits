import 'package:flutter/material.dart' show DateUtils;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/daily_summary.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';

/// Typed CRUD wrappers around the five Supabase tables. RLS scopes every
/// row to the signed-in user, so callers never need to pass a user id filter
/// explicitly for reads that already go through `.eq('user_id', uid)` below —
/// it's kept explicit for readability and to make query intent obvious.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  // --- users -----------------------------------------------------------

  Future<UserProfile?> fetchProfile() async {
    final row =
        await _client.from('users').select().eq('id', _uid).maybeSingle();
    return row == null ? null : UserProfile.fromMap(row);
  }

  // --- accounts ----------------------------------------------------------

  Future<List<Account>> fetchAccounts() async {
    final rows = await _client
        .from('accounts')
        .select()
        .eq('user_id', _uid)
        .order('institution_name');
    return rows.map(Account.fromMap).toList();
  }

  Future<Account> upsertAccount(Account account) async {
    final row = await _client
        .from('accounts')
        .upsert(account.toInsertMap())
        .select()
        .single();
    return Account.fromMap(row);
  }

  // --- transactions --------------------------------------------------------

  Future<List<TransactionModel>> fetchTransactions({
    bool foodDeliveryOnly = false,
    DateTime? since,
  }) async {
    var query = _client.from('transactions').select().eq('user_id', _uid);
    if (foodDeliveryOnly) {
      query = query.eq('is_food_delivery', true);
    }
    if (since != null) {
      query = query.gte('date', since.toIso8601String().split('T').first);
    }
    final rows = await query.order('date', ascending: false);
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    final row = await _client
        .from('transactions')
        .insert(transaction.toInsertMap())
        .select()
        .single();
    final saved = TransactionModel.fromMap(row);
    if (saved.isFoodDelivery) {
      await recomputeMonthSummaries(DateTime(saved.date.year, saved.date.month));
    }
    return saved;
  }

  Future<void> updateTransactionNote(String id, String? note) async {
    await _client.from('transactions').update({'note': note}).eq('id', id);
  }

  Future<List<TransactionModel>> fetchTransactionsForDay(DateTime day) async {
    final dateStr = day.toIso8601String().split('T').first;
    final rows = await _client
        .from('transactions')
        .select()
        .eq('user_id', _uid)
        .eq('date', dateStr)
        .order('created_at', ascending: false);
    return rows.map(TransactionModel.fromMap).toList();
  }

  // --- budgets -------------------------------------------------------------

  Future<Budget?> fetchBudget() async {
    final row =
        await _client.from('budgets').select().eq('user_id', _uid).maybeSingle();
    return row == null ? null : Budget.fromMap(row);
  }

  Future<Budget> upsertBudget(Budget budget) async {
    final row = await _client
        .from('budgets')
        .upsert(budget.toInsertMap(), onConflict: 'user_id')
        .select()
        .single();
    return Budget.fromMap(row);
  }

  Future<double> sumFoodDeliverySpent({required DateTime from, required DateTime to}) async {
    final rows = await _client
        .from('transactions')
        .select('amount')
        .eq('user_id', _uid)
        .eq('is_food_delivery', true)
        .gte('date', from.toIso8601String().split('T').first)
        .lte('date', to.toIso8601String().split('T').first);
    var total = 0.0;
    for (final row in rows) {
      total += (row['amount'] as num).toDouble();
    }
    return total;
  }

  // --- daily_summaries -------------------------------------------------------

  Future<List<DailySummary>> fetchDailySummaries({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('daily_summaries')
        .select()
        .eq('user_id', _uid)
        .gte('date', from.toIso8601String().split('T').first)
        .lte('date', to.toIso8601String().split('T').first)
        .order('date');
    return rows.map(DailySummary.fromMap).toList();
  }

  /// Recomputes and upserts every `daily_summaries` row for [month] (up to
  /// today, if [month] is the current month) from the food-delivery
  /// transactions on file. `amount_saved` is the signed net for that day
  /// (daily budget allocation minus spent) — negative means overspent — which
  /// is exactly what the Home calendar renders.
  Future<void> recomputeMonthSummaries(DateTime month) async {
    final budget = await fetchBudget();
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final isCurrentMonth = now.year == month.year && now.month == month.month;
    final lastDay = isCurrentMonth ? now.day : daysInMonth;
    final dailyAllocation = (budget?.monthlyBudgetAmount ?? 0) / daysInMonth;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month, lastDay);
    final txnRows = await _client
        .from('transactions')
        .select('date, amount')
        .eq('user_id', _uid)
        .eq('is_food_delivery', true)
        .gte('date', monthStart.toIso8601String().split('T').first)
        .lte('date', monthEnd.toIso8601String().split('T').first);

    final spentByDay = <int, double>{};
    for (final row in txnRows) {
      final day = DateTime.parse(row['date'] as String).day;
      spentByDay[day] = (spentByDay[day] ?? 0) + (row['amount'] as num).toDouble();
    }

    final upsertRows = [
      for (var day = 1; day <= lastDay; day++)
        {
          'user_id': _uid,
          'date': DateTime(month.year, month.month, day).toIso8601String().split('T').first,
          'amount_spent': spentByDay[day] ?? 0,
          'amount_saved': dailyAllocation - (spentByDay[day] ?? 0),
        },
    ];
    if (upsertRows.isEmpty) return;
    await _client.from('daily_summaries').upsert(upsertRows, onConflict: 'user_id,date');
  }
}
