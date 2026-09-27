import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;
import 'package:http/http.dart' as http;

/// Wraps Firebase Auth + Google Sign-In. Identity (who the user is) and
/// authorization (Drive access) are requested together but handled
/// separately, per google_sign_in 7.x's split model — see
/// docs/ARCHITECTURE.md#technical-architecture.
///
/// Web and native platforms use different flows because Firebase's web SDK
/// can grant Drive scopes directly via signInWithPopup, while native
/// platforms need the google_sign_in plugin for identity plus a separate
/// authorization step for Drive.
class AuthRepository {
  AuthRepository() : _initGoogleSignIn = kIsWeb ? null : _initialize();

  /// The OAuth "Web client" Firebase auto-created for this project — needed
  /// as `serverClientId` so the Android sign-in flow returns an idToken
  /// Firebase can verify. Public identifier, not a secret.
  static const _androidServerClientId =
      '311213523049-i8p29ria6n42ajlcl357184hm1mlfvkv.apps.googleusercontent.com';

  static const driveScopes = [drive.DriveApi.driveFileScope];

  static Future<void> _initialize() {
    return GoogleSignIn.instance.initialize(
      serverClientId: _androidServerClientId,
    );
  }

  final Future<void>? _initGoogleSignIn;
  final _auth = fb.FirebaseAuth.instance;

  String? _driveAccessToken;

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();
  fb.User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = fb.GoogleAuthProvider()
        ..addScope(drive.DriveApi.driveFileScope);
      final userCredential = await _auth.signInWithPopup(provider);
      final oauth = userCredential.credential as fb.OAuthCredential?;
      _driveAccessToken = oauth?.accessToken;
      return;
    }

    await _initGoogleSignIn;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);

    final authorization = await account.authorizationClient.authorizeScopes(
      driveScopes,
    );
    _driveAccessToken = authorization.accessToken;
  }

  Future<void> signOut() async {
    _driveAccessToken = null;
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  /// A googleapis-compatible HTTP client authorized for Drive, or null if
  /// Drive access hasn't been granted this session (re-sign-in to fix).
  http.Client? driveHttpClient() {
    final token = _driveAccessToken;
    if (token == null) return null;
    final credentials = gapis.AccessCredentials(
      gapis.AccessToken(
        'Bearer',
        token,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      driveScopes,
    );
    return gapis.authenticatedClient(http.Client(), credentials);
  }
}
