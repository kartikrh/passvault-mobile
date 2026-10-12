// Wraps google_sign_in to get the idToken PassVaultapi's POST /vault/auth/google
// verifies (googleSignInService's verifyGoogleIdToken, audience = this
// White Label's googleKeyMobile -- a separate OAuth client from the web
// app's googleKey, since a mobile request is tagged via X-Client-Platform).
// NOTE: unlike the rest of this app, this needs real per-project setup this
// codebase can't generate on its own -- android/app/google-services.json
// (from Firebase/Google Cloud console) and a registered SHA-1 signing
// fingerprint, and (for iOS) a REVERSED_CLIENT_ID URL scheme in Info.plist.
// Until that's done, signInAndGetIdToken throws.
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  /// [serverClientId] is the White Label's `googleKeyMobile` (a Web OAuth
  /// client ID registered for this app, per Google's own recommendation for
  /// server-side ID token verification) -- passing it as serverClientId is
  /// what makes GoogleSignIn request an idToken audienced for that client,
  /// matching what verifyGoogleIdToken(idToken, whitelabel.googleKeyMobile)
  /// expects, rather than an Android-client-audienced token that would fail
  /// verification.
  GoogleAuthService(String serverClientId)
      : _googleSignIn = GoogleSignIn(scopes: ['email'], serverClientId: serverClientId);

  final GoogleSignIn _googleSignIn;

  Future<String> signInAndGetIdToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in was cancelled.');
    }
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) {
      throw Exception('Google did not return an ID token.');
    }
    return idToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
