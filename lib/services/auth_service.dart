import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_config.dart';

/// Wraps Supabase Auth plus the native Google/Apple sign-in flows. Google and
/// Apple are code-complete but inert until real OAuth client IDs are supplied
/// — see SETUP.md.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;
  bool _googleInitialized = false;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'first_name': firstName},
    );
  }

  Future<void> signInWithEmail({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleSignInServerClientId.isEmpty
          ? null
          : AppConfig.googleSignInServerClientId,
    );
    _googleInitialized = true;
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple sign-in did not return an identity token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
