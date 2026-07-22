import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/transaction.dart';
import 'auth_provider.dart';

final transactionsFoodDeliveryOnlyProvider = StateProvider<bool>((ref) => false);
final transactionsSearchProvider = StateProvider<String>((ref) => '');

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) {
  final foodOnly = ref.watch(transactionsFoodDeliveryOnlyProvider);
  return ref.watch(supabaseServiceProvider).fetchTransactions(foodDeliveryOnly: foodOnly);
});

final filteredTransactionsProvider = Provider<AsyncValue<List<TransactionModel>>>((ref) {
  final search = ref.watch(transactionsSearchProvider).trim().toLowerCase();
  final transactionsAsync = ref.watch(transactionsProvider);
  if (search.isEmpty) return transactionsAsync;
  return transactionsAsync.whenData(
    (list) => list.where((t) => t.merchantName.toLowerCase().contains(search)).toList(),
  );
});
