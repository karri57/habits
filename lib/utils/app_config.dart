/// Reads secrets injected at build time via --dart-define-from-file=dart_define.json.
/// See dart_define.example.json for the required keys and SETUP.md for where to get them.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const plaidPublicKey = String.fromEnvironment('PLAID_PUBLIC_KEY');
  static const plaidEnv = String.fromEnvironment('PLAID_ENV', defaultValue: 'sandbox');
  static const googleSignInServerClientId =
      String.fromEnvironment('GOOGLE_SIGN_IN_SERVER_CLIENT_ID');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && !supabaseUrl.contains('placeholder');

  static bool get isPlaidConfigured =>
      plaidPublicKey.isNotEmpty && !plaidPublicKey.contains('placeholder');

  static bool get isGoogleSignInConfigured =>
      googleSignInServerClientId.isNotEmpty &&
      !googleSignInServerClientId.contains('placeholder');
}
