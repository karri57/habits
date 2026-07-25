import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_products.dart';
import 'supabase_service.dart';

/// Wraps `in_app_purchase` for the Delivery Habits PRO subscription.
///
/// v1 limitation: purchase status is trusted client-side (no server-side
/// receipt verification) — acceptable for an initial launch, but a
/// determined user could spoof "pro" locally. Revisit with a Supabase Edge
/// Function verifying the App Store/Play receipt before flipping `is_pro`
/// once this matters (e.g. once Plaid usage carries real API cost).
class PurchaseService {
  PurchaseService(this._iap, this._supabaseService);

  final InAppPurchase _iap;
  final SupabaseService _supabaseService;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  void init() {
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void dispose() => _subscription?.cancel();

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<ProductDetailsResponse> queryProducts() =>
      _iap.queryProductDetails(PurchaseProducts.all);

  Future<bool> buy(ProductDetails product) {
    return _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final expiresAt = DateTime.now().add(
          purchase.productID == PurchaseProducts.monthly
              ? const Duration(days: 31)
              : const Duration(days: 366),
        );
        await _supabaseService.setProStatus(isPro: true, expiresAt: expiresAt);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }
}
