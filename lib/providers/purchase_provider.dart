import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/purchase_service.dart';
import 'auth_provider.dart';
import 'profile_provider.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService(InAppPurchase.instance, ref.watch(supabaseServiceProvider));
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

/// Keyed by product ID for easy lookup in the paywall screens.
final purchaseProductsProvider = FutureProvider<Map<String, ProductDetails>>((ref) async {
  final response = await ref.watch(purchaseServiceProvider).queryProducts();
  return {for (final p in response.productDetails) p.id: p};
});

/// True once the signed-in user's profile shows an active Pro subscription.
final isProProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null || !profile.isPro) return false;
  final expiresAt = profile.proExpiresAt;
  return expiresAt == null || expiresAt.isAfter(DateTime.now());
});
