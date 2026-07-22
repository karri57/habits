class UserProfile {
  const UserProfile({required this.id, required this.email, this.firstName});

  final String id;
  final String email;
  final String? firstName;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        email: map['email'] as String,
        firstName: map['first_name'] as String?,
      );
}
