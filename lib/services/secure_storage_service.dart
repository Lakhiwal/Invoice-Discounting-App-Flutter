import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SecureStorageService  — fix #5 applied:
//
//  BEFORE: saved the raw password alongside the email. On biometric login,
//  the app replayed the password to the server. This means a compromised
//  Keystore (rooted device, OS migration) leaks user credentials.
//
//  AFTER: saves only the refresh token. The biometric login path calls
//  ApiService._refreshAccessToken() to get a new access token instead of
//  replaying the password. The email is still stored as a display hint
//  (shown on the lock/login screen), but never used for auth.
//
//  Migration: existing users who have a saved password will have it cleared
//  the next time clearCredentials() is called (logout). On next login,
//  only the refresh token is saved.
// ─────────────────────────────────────────────────────────────────────────────

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _emailKey = 'secure_email';
  static const _refreshTokenKey = 'secure_refresh_token';

  // Legacy key — kept only for migration wipe on clearCredentials()
  static const _legacyPasswordKey = 'secure_password';

  // ── JWT Token Keys (P0 security hardening) ───────────────────────────────
  static const _accessTokenKey = 'jwt_access_token';
  static const _jwtRefreshKey = 'jwt_refresh_token';

  // ════════════════════════════════════════════════════════════════════════════
  // JWT TOKEN MANAGEMENT — used by ApiClient for all authenticated requests
  // ════════════════════════════════════════════════════════════════════════════

  /// Save both JWT tokens after login or token refresh.
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _jwtRefreshKey, value: refreshToken);
  }

  /// Save only the access token (after a refresh).
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Read the current access token (may be null if not logged in).
  static Future<String?> getAccessToken() async =>
      _storage.read(key: _accessTokenKey);

  /// Read the current refresh token.
  static Future<String?> getRefreshToken() async =>
      _storage.read(key: _jwtRefreshKey);

  /// Clear JWT tokens on logout.
  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _jwtRefreshKey);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BIOMETRIC CREDENTIALS — email hint + refresh token for biometric re-auth
  // ════════════════════════════════════════════════════════════════════════════

  /// Save email (display hint) + refresh token after a successful login.
  static Future<void> saveCredentials({
    required String email,
    required String refreshToken,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    // Wipe any legacy password that may have been written by an older version
    await _storage.delete(key: _legacyPasswordKey);
  }

  /// Returns the stored email hint and refresh token.
  /// Both may be null if nothing has been saved yet.
  static Future<Map<String, String?>> getCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    return {'email': email, 'refreshToken': refreshToken};
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacyPasswordKey); // legacy wipe
  }

  /// Clear everything on full logout.
  static Future<void> clearAll() async {
    await clearTokens();
    await clearCredentials();
  }
}
