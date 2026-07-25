import 'package:delivery_habits/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'has_seen_welcome': true});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      publishableKey: 'placeholder-publishable-key',
    );
  });

  testWidgets('shows the auth screen when signed out', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DeliveryHabitsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Habits'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
