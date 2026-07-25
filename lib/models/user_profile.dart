class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.firstName,
    required this.isPro,
    this.proExpiresAt,
  });

  final String id;
  final String email;
  final String? firstName;
  final bool isPro;
  final DateTime? proExpiresAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        email: map['email'] as String,
        firstName: map['first_name'] as String?,
        isPro: map['is_pro'] as bool? ?? false,
        proExpiresAt: map['pro_expires_at'] == null
            ? null
            : DateTime.parse(map['pro_expires_at'] as String),
      );
}
