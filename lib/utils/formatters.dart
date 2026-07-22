import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _currencyFormatWhole = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

String formatCurrency(double value) => _currencyFormat.format(value);

String formatCurrencyWhole(double value) => _currencyFormatWhole.format(value);

/// e.g. "+12%" or "-8%". Returns "+0%" when [previous] is zero and [current] is zero too.
String formatPercentChange(double current, double previous) {
  if (previous == 0) {
    if (current == 0) return '+0%';
    return current > 0 ? '+100%' : '-100%';
  }
  final change = ((current - previous) / previous.abs()) * 100;
  final sign = change >= 0 ? '+' : '';
  return '$sign${change.toStringAsFixed(0)}%';
}

String timeOfDayGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

/// e.g. "3h ago", "2d ago". [dt] must be in the past.
String formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
