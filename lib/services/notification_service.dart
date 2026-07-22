import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/formatters.dart';

/// Local-only budget threshold alerts (no backend push needed for v1). Fires
/// at most once per cycle per threshold — state tracked in SharedPreferences
/// keyed by cycle-start date, so re-checking on every screen load doesn't spam.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> checkBudgetThresholds({
    required double spent,
    required double budgetAmount,
    required bool notify75,
    required bool notify100,
    required DateTime cycleStart,
  }) async {
    if (budgetAmount <= 0) return;
    final ratio = spent / budgetAmount;
    final cycleKey = cycleStart.toIso8601String().split('T').first;

    if (notify100 && ratio >= 1.0) {
      await _notifyOnce(
        thresholdKey: '100_$cycleKey',
        id: 100,
        title: 'Delivery budget exceeded',
        body:
            'You\'ve spent ${formatCurrency(spent)} of your ${formatCurrency(budgetAmount)} budget this cycle.',
      );
    } else if (notify75 && ratio >= 0.75) {
      await _notifyOnce(
        thresholdKey: '75_$cycleKey',
        id: 75,
        title: '75% of delivery budget used',
        body: 'You\'ve used ${formatCurrency(spent)} of your ${formatCurrency(budgetAmount)} budget this cycle.',
      );
    }
  }

  Future<void> _notifyOnce({
    required String thresholdKey,
    required int id,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefsKey = 'notified_$thresholdKey';
    if (prefs.getBool(prefsKey) == true) return;

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alerts when you approach or exceed your delivery budget',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
    await prefs.setBool(prefsKey, true);
  }
}
