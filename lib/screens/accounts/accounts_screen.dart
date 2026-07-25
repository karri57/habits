import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../providers/accounts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import 'link_account_button.dart';

enum _TimeRange { m1, m3, m6, ytd, y1, all }

extension on _TimeRange {
  String get label => switch (this) {
        _TimeRange.m1 => '1M',
        _TimeRange.m3 => '3M',
        _TimeRange.m6 => '6M',
        _TimeRange.ytd => 'YTD',
        _TimeRange.y1 => '1Y',
        _TimeRange.all => 'ALL',
      };
}

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  _TimeRange _range = _TimeRange.m1;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(balanceViewProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(accountsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<BalanceView>(
            segments: const [
              ButtonSegment(value: BalanceView.netWorth, label: Text('Net Worth')),
              ButtonSegment(value: BalanceView.cash, label: Text('Cash')),
            ],
            selected: {view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => ref.read(balanceViewProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 20),
          accountsAsync.when(
            data: (accounts) {
              final total = view == BalanceView.netWorth ? accounts.netWorthTotal : accounts.cashTotal;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatCurrencyWhole(total),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accounts.isEmpty
                        ? 'Link an account to see your balance history'
                        : '+\$0, 1 month', // No balance-history table yet — see SETUP.md.
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final r in _TimeRange.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(r.label),
                              selected: _range == r,
                              onSelected: (_) => setState(() => _range = r),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Linked accounts',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final account in accounts) _AccountRow(account: account),
                  const SizedBox(height: 12),
                  const LinkAccountButton(),
                  const SizedBox(height: 32),
                  Text(
                    'Settings',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.red),
                      title: const Text('Sign out'),
                      onTap: () => ref.read(authServiceProvider).signOut(),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(child: Text('Couldn\'t load accounts: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                account.institutionName.isNotEmpty ? account.institutionName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.accountName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${account.institutionName} · ${account.type}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (account.lastSyncedAt != null)
                    Text(
                      'Last synced ${formatRelativeTime(account.lastSyncedAt!)}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
            Text(formatCurrency(account.currentBalance),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
