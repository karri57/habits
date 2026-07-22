import '../models/platform.dart';

/// Matches a raw merchant name (as reported by Plaid or typed manually) against
/// known food-delivery brands so transactions can be auto-tagged.
class MerchantMatcher {
  MerchantMatcher._();

  static const Map<DeliveryPlatform, List<String>> _brandKeywords = {
    DeliveryPlatform.doordash: ['DOORDASH', 'DOOR DASH'],
    DeliveryPlatform.ubereats: ['UBER EATS', 'UBEREATS', 'UBER *EATS'],
    DeliveryPlatform.grubhub: ['GRUBHUB', 'GRUB HUB', 'SEAMLESS'],
    DeliveryPlatform.other: ['POSTMATES', 'INSTACART', 'GOPUFF'],
  };

  /// Returns the matched platform, or null if [merchantName] isn't a known
  /// food-delivery brand.
  static DeliveryPlatform? match(String merchantName) {
    final normalized = merchantName.toUpperCase();
    for (final entry in _brandKeywords.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) return entry.key;
      }
    }
    return null;
  }

  static bool isFoodDelivery(String merchantName) => match(merchantName) != null;
}
