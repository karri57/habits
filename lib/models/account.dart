class Account {
  const Account({
    required this.id,
    required this.userId,
    this.plaidAccountId,
    required this.institutionName,
    required this.accountName,
    required this.type,
    required this.currentBalance,
    this.lastSyncedAt,
  });

  final String id;
  final String userId;
  final String? plaidAccountId;
  final String institutionName;
  final String accountName;
  final String type;
  final double currentBalance;
  final DateTime? lastSyncedAt;

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        plaidAccountId: map['plaid_account_id'] as String?,
        institutionName: map['institution_name'] as String,
        accountName: map['account_name'] as String,
        type: map['type'] as String,
        currentBalance: (map['current_balance'] as num).toDouble(),
        lastSyncedAt: map['last_synced_at'] == null
            ? null
            : DateTime.parse(map['last_synced_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'plaid_account_id': plaidAccountId,
        'institution_name': institutionName,
        'account_name': accountName,
        'type': type,
        'current_balance': currentBalance,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };
}
