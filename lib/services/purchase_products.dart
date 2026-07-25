/// Subscription product IDs — must exactly match the products created in
/// App Store Connect (Subscriptions) and, later, Google Play Console.
/// See SETUP.md for how to create them.
class PurchaseProducts {
  PurchaseProducts._();

  static const monthly = 'com.deliveryhabits.deliveryHabits.pro.monthly';
  static const yearly = 'com.deliveryhabits.deliveryHabits.pro.yearly';

  /// The discounted "hold up... this is a limited offer" retention screen,
  /// shown when someone dismisses the main paywall — a separate product
  /// since StoreKit promotional-offer signing is out of scope for v1.
  static const yearlyOffer = 'com.deliveryhabits.deliveryHabits.pro.yearly.offer';

  static const all = {monthly, yearly, yearlyOffer};

  static bool isYearlyType(String productId) => productId != monthly;
}
