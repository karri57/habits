import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(supabaseClientProvider)));

final supabaseServiceProvider =
    Provider<SupabaseService>((ref) => SupabaseService(ref.watch(supabaseClientProvider)));

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);

/// The signed-in user, or null. Reactive to sign-in/sign-out.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? ref.watch(supabaseClientProvider).auth.currentUser;
});
