import 'package:flutter/material.dart';

enum DeliveryPlatform { doordash, ubereats, grubhub, other }

extension DeliveryPlatformX on DeliveryPlatform {
  static DeliveryPlatform? fromDb(String? value) {
    switch (value) {
      case 'doordash':
        return DeliveryPlatform.doordash;
      case 'ubereats':
        return DeliveryPlatform.ubereats;
      case 'grubhub':
        return DeliveryPlatform.grubhub;
      case 'other':
        return DeliveryPlatform.other;
      default:
        return null;
    }
  }

  String get dbValue => name;

  String get label {
    switch (this) {
      case DeliveryPlatform.doordash:
        return 'DoorDash';
      case DeliveryPlatform.ubereats:
        return 'Uber Eats';
      case DeliveryPlatform.grubhub:
        return 'Grubhub';
      case DeliveryPlatform.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case DeliveryPlatform.doordash:
        return const Color(0xFFFF3008);
      case DeliveryPlatform.ubereats:
        return const Color(0xFF06C167);
      case DeliveryPlatform.grubhub:
        return const Color(0xFFFF8000);
      case DeliveryPlatform.other:
        return const Color(0xFF9A9AA5);
    }
  }

  IconData get icon {
    switch (this) {
      case DeliveryPlatform.doordash:
      case DeliveryPlatform.ubereats:
      case DeliveryPlatform.grubhub:
        return Icons.delivery_dining;
      case DeliveryPlatform.other:
        return Icons.receipt_long;
    }
  }
}
