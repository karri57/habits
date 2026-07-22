import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'auth_provider.dart';

final userProfileProvider = FutureProvider<UserProfile?>(
  (ref) => ref.watch(supabaseServiceProvider).fetchProfile(),
);
