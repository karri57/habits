import 'platform.dart';

enum TransactionSource { plaid, manual }

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    this.accountId,
    required this.merchantName,
    required this.amount,
    required this.date,
    this.platform,
    required this.isFoodDelivery,
    required this.source,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? accountId;
  final String merchantName;
  final double amount;
  final DateTime date;
  final DeliveryPlatform? platform;
  final bool isFoodDelivery;
  final TransactionSource source;
  final String? note;

  /// The `date` column has no time-of-day (it's a DATE), so the Home
  /// bottom sheet and Transactions detail view show this instead as the
  /// order's approximate time.
  final DateTime createdAt;

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        accountId: map['account_id'] as String?,
        merchantName: map['merchant_name'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        platform: DeliveryPlatformX.fromDb(map['platform'] as String?),
        isFoodDelivery: map['is_food_delivery'] as bool,
        source: (map['source'] as String) == 'plaid'
            ? TransactionSource.plaid
            : TransactionSource.manual,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'account_id': accountId,
        'merchant_name': merchantName,
        'amount': amount,
        'date': date.toIso8601String().split('T').first,
        'platform': platform?.dbValue,
        'is_food_delivery': isFoodDelivery,
        'source': source.name,
        'note': note,
      };
}
