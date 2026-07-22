import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/account.dart';
import '../services/plaid_service.dart';
import 'auth_provider.dart';

final plaidServiceProvider = Provider<PlaidService>(
  (ref) => PlaidService(ref.watch(supabaseClientProvider)),
);

final accountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(supabaseServiceProvider).fetchAccounts(),
);

enum BalanceView { netWorth, cash }

final balanceViewProvider = StateProvider<BalanceView>((ref) => BalanceView.netWorth);

const _cashAccountTypes = {'checking', 'savings'};

extension AccountListX on List<Account> {
  double get netWorthTotal => fold(0, (sum, a) => sum + a.currentBalance);

  double get cashTotal => where((a) => _cashAccountTypes.contains(a.type.toLowerCase()))
      .fold(0, (sum, a) => sum + a.currentBalance);
}
