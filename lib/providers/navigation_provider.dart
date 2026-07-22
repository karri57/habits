import 'package:flutter_riverpod/legacy.dart';

/// Mirrors RootShell's TabController index so other screens (e.g. Home's
/// "set up your budget" nudge) can switch tabs without a BuildContext lookup.
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);
