import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  AuthRepository() : _initGoogleSignIn = _initialize();

  /// The OAuth "Web client" Firebase auto-created for this project. Used as
  /// `serverClientId` on native so the Android sign-in flow returns an
  /// idToken Firebase can verify, and as `clientId` on web so the
  /// google_sign_in plugin's GIS-backed authorization client (used for
  /// silent Drive token refresh — see [_silentlyRefreshDriveToken]) has a
  /// client to talk to. Public identifier, not a secret.
  static const _webClientId =
      '311213523049-i8p29ria6n42ajlcl357184hm1mlfvkv.apps.googleusercontent.com';

  static const driveScopes = [drive.DriveApi.driveFileScope];

  static const _storage = FlutterSecureStorage();
  static const _tokenKeyPrefix = 'drive_access_token_';
  static const _expiryKeyPrefix = 'drive_token_expiry_';

  /// Refresh a bit before the real expiry so a request never races an
  /// almost-expired token.
  static const _expiryBuffer = Duration(minutes: 2);

  /// Debug-only sign-in tracing — never runs in release builds, since it
  /// can include the signed-in user's email/uid and raw auth exceptions.
  static void _log(String message) {
    if (kDebugMode) debugPrint('[GoogleSignIn] $message');
  }

  static Future<void> _initialize() {
    return GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? _webClientId : null,
      serverClientId: kIsWeb ? null : _webClientId,
    );
  }

  final Future<void>? _initGoogleSignIn;
  final _auth = fb.FirebaseAuth.instance;

  String? _driveAccessToken;
  DateTime? _driveTokenExpiry;

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();
  fb.User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    _log('signInWithGoogle start (kIsWeb=$kIsWeb)');
    if (kIsWeb) {
      final provider = fb.GoogleAuthProvider()
        ..addScope(drive.DriveApi.driveFileScope);
      try {
        final userCredential = await _auth.signInWithPopup(provider);
        final oauth = userCredential.credential as fb.OAuthCredential?;
        await _setDriveToken(oauth?.accessToken, const Duration(hours: 1));
        _log('web signInWithPopup succeeded');
      } catch (e, st) {
        _log('web signInWithPopup FAILED: $e\n$st');
        rethrow;
      }
      return;
    }

    try {
      await _initGoogleSignIn;
      _log('initialize complete, calling authenticate()');
      final account = await GoogleSignIn.instance.authenticate();
      _log('authenticate() succeeded');

      final idToken = account.authentication.idToken;
      _log('idToken present: ${idToken != null}');
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);

      await _auth.signInWithCredential(credential);
      _log('Firebase signInWithCredential succeeded');

      final authorization = await account.authorizationClient.authorizeScopes(
        driveScopes,
      );
      await _setDriveToken(authorization.accessToken, const Duration(hours: 1));
      _log(
        'Drive authorizeScopes succeeded '
        '(accessToken present: ${_driveAccessToken != null})',
      );
    } on GoogleSignInException catch (e) {
      _log('GoogleSignInException: code=${e.code}');
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      _log('FirebaseAuthException: code=${e.code}');
      rethrow;
    } catch (e) {
      _log('Unexpected error: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _clearDriveToken();
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  String? get _uid => currentUser?.uid;

  Future<void> _setDriveToken(String? token, Duration ttl) async {
    _driveAccessToken = token;
    final uid = _uid;
    if (token == null || uid == null) return;
    _driveTokenExpiry = DateTime.now().toUtc().add(ttl);
    await _storage.write(key: '$_tokenKeyPrefix$uid', value: token);
    await _storage.write(
      key: '$_expiryKeyPrefix$uid',
      value: _driveTokenExpiry!.toIso8601String(),
    );
  }

  Future<void> _clearDriveToken() async {
    _driveAccessToken = null;
    _driveTokenExpiry = null;
    final uid = _uid;
    if (uid == null) return;
    await _storage.delete(key: '$_tokenKeyPrefix$uid');
    await _storage.delete(key: '$_expiryKeyPrefix$uid');
  }

  /// Restores a previously-persisted Drive token for the current user, if
  /// any exists and hasn't expired. Called lazily from [driveHttpClient]
  /// so a fresh app launch doesn't need an interactive sign-in just to
  /// reuse a still-valid token from a prior session.
  Future<void> _restoreDriveTokenFromStorage() async {
    final uid = _uid;
    if (uid == null) return;
    final token = await _storage.read(key: '$_tokenKeyPrefix$uid');
    final expiryRaw = await _storage.read(key: '$_expiryKeyPrefix$uid');
    if (token == null || expiryRaw == null) return;
    final expiry = DateTime.tryParse(expiryRaw);
    if (expiry == null) return;
    _driveAccessToken = token;
    _driveTokenExpiry = expiry;
  }

  bool get _driveTokenValid {
    final expiry = _driveTokenExpiry;
    if (_driveAccessToken == null || expiry == null) return false;
    return DateTime.now().toUtc().isBefore(expiry.subtract(_expiryBuffer));
  }

  /// Silently requests a fresh Drive access token from the Google Sign-In
  /// session (no UI), for when the cached token has expired. Works on web
  /// too — google_sign_in 7.x's GIS-backed authorization client can restore
  /// a still-valid browser session and previously-granted Drive scope
  /// without a popup, unlike a plain `signInWithPopup` token (which Firebase
  /// exposes no refresh path for). Falls through to null if the browser
  /// can't silently restore a session (e.g. third-party cookies/FedCM
  /// blocked, or scope never granted), in which case the caller needs an
  /// interactive reconnect.
  Future<bool> _silentlyRefreshDriveToken() async {
    try {
      await _initGoogleSignIn;
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account == null) return false;
      final authorization = await account.authorizationClient
          .authorizationForScopes(driveScopes);
      if (authorization == null) return false;
      await _setDriveToken(authorization.accessToken, const Duration(hours: 1));
      _log('Silent Drive token refresh succeeded');
      return true;
    } catch (e) {
      _log('Silent Drive token refresh failed: $e');
      return false;
    }
  }

  /// Interactive fallback for when [_silentlyRefreshDriveToken] can't
  /// restore access on its own (browser/session blocked silent auth, or
  /// Drive access was revoked/never granted). Reuses the already-signed-in
  /// Firebase user — this only re-asks for Drive, not identity.
  Future<void> reauthorizeDrive() async {
    if (kIsWeb) {
      final user = _auth.currentUser;
      if (user == null) throw StateError('Not signed in.');
      final provider = fb.GoogleAuthProvider()
        ..addScope(drive.DriveApi.driveFileScope);
      final userCredential = await user.reauthenticateWithPopup(provider);
      final oauth = userCredential.credential as fb.OAuthCredential?;
      await _setDriveToken(oauth?.accessToken, const Duration(hours: 1));
      return;
    }

    await _initGoogleSignIn;
    final account = await GoogleSignIn.instance.attemptLightweightAuthentication() ??
        await GoogleSignIn.instance.authenticate();
    final authorization = await account.authorizationClient.authorizeScopes(
      driveScopes,
    );
    await _setDriveToken(authorization.accessToken, const Duration(hours: 1));
  }

  /// A googleapis-compatible HTTP client authorized for Drive, or null if
  /// Drive access hasn't been granted and couldn't be silently restored or
  /// refreshed (interactive re-sign-in is required to fix that).
  Future<http.Client?> driveHttpClient() async {
    if (!_driveTokenValid) {
      await _restoreDriveTokenFromStorage();
    }
    if (!_driveTokenValid) {
      await _silentlyRefreshDriveToken();
    }
    if (!_driveTokenValid) return null;

    final credentials = gapis.AccessCredentials(
      gapis.AccessToken('Bearer', _driveAccessToken!, _driveTokenExpiry!),
      null,
      driveScopes,
    );
    return gapis.authenticatedClient(http.Client(), credentials);
  }
}
