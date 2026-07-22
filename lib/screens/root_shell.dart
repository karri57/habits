import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/notification_provider.dart';
import 'accounts/accounts_screen.dart';
import 'budget/budget_screen.dart';
import 'home/home_screen.dart';
import 'spending/spending_screen.dart';
import 'transactions/transactions_screen.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = [
  _TabSpec('Home', Icons.home_outlined),
  _TabSpec('Spending', Icons.bar_chart_outlined),
  _TabSpec('Accounts', Icons.account_balance_outlined),
  _TabSpec('Transactions', Icons.receipt_long_outlined),
  _TabSpec('Budget', Icons.pie_chart_outline),
];

/// Persists the selected tab across app launches (see [_prefsKey]).
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> with SingleTickerProviderStateMixin {
  static const _prefsKey = 'last_tab_index';

  late final TabController _tabController;
  int _lastSavedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_persistIndexIfChanged);
    _restoreTabIndex();
    ref.read(notificationServiceProvider).initialize();
  }

  Future<void> _restoreTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefsKey) ?? 0;
    if (mounted && saved > 0 && saved < _tabs.length) {
      _tabController.index = saved;
      _lastSavedIndex = saved;
      ref.read(selectedTabIndexProvider.notifier).state = saved;
    }
  }

  void _persistIndexIfChanged() {
    final index = _tabController.index;
    if (index == _lastSavedIndex) return;
    _lastSavedIndex = index;
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_prefsKey, index));
    ref.read(selectedTabIndexProvider.notifier).state = index;
  }

  @override
  void dispose() {
    _tabController.removeListener(_persistIndexIfChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(selectedTabIndexProvider, (previous, next) {
      if (_tabController.index != next) _tabController.animateTo(next);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final tab in _tabs) Tab(icon: Icon(tab.icon), text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          HomeScreen(),
          SpendingScreen(),
          AccountsScreen(),
          TransactionsScreen(),
          BudgetScreen(),
        ],
      ),
    );
  }
}
