import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:invoice_discounting_app/config.dart';
import 'package:invoice_discounting_app/services/secure_storage_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ApiClient — Core HTTP plumbing with auto-refresh on 401/403
// ═══════════════════════════════════════════════════════════════════════════════

/// Thrown when the user is unauthenticated and refresh failed.
/// UI should catch this and navigate to login.
class UnauthorizedException implements Exception {
  const UnauthorizedException([
    this.message = 'Session expired. Please log in again.',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// Core HTTP client with JWT token management and automatic retry.
/// All domain-specific API services delegate to this class.
class ApiClient {
  static const String baseUrl = '${AppConfig.baseUrl}/api';

  // ── Timeout ──
  static const _timeout = Duration(seconds: 30);

  static http.Response _timeoutResponse() => http.Response(
        '{"error":"Request timed out. Check your connection."}',
        408,
      );

  // ── Token Management ──

  static Future<String?> getAccessToken() async =>
      SecureStorageService.getAccessToken();

  static Future<String?> getRefreshToken() async =>
      SecureStorageService.getRefreshToken();

  static Future<void> saveTokens(String access, String refresh) async {
    await SecureStorageService.saveTokens(
      accessToken: access,
      refreshToken: refresh,
    );
  }

  static Future<void> saveAccessToken(String access) async {
    await SecureStorageService.saveAccessToken(access);
  }

  // ── Headers ──

  static Future<Map<String, String>> authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> get publicHeaders => {
        'Content-Type': 'application/json',
      };

  // ── Token Refresh ──

  static Future<bool>? _refreshFuture;

  static Future<bool> refreshAccessToken() async {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _performRefresh();
    final result = await _refreshFuture!;
    _refreshFuture = null;
    return result;
  }

  static Future<bool> _performRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh/'),
            headers: publicHeaders,
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(_timeout, onTimeout: _timeoutResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['access'] as String?;
        if (newAccess != null) {
          await saveAccessToken(newAccess);
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Smart HTTP methods — auto-refresh on 401/403
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<http.Response> get(String url) async {
    var response = await http
        .get(Uri.parse(url), headers: await authHeaders())
        .timeout(_timeout, onTimeout: _timeoutResponse);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .get(Uri.parse(url), headers: await authHeaders())
          .timeout(_timeout, onTimeout: _timeoutResponse);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  static Future<http.Response> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    var response = await http
        .post(
          Uri.parse(url),
          headers: await authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _timeoutResponse);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .post(
            Uri.parse(url),
            headers: await authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout, onTimeout: _timeoutResponse);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  static Future<http.Response> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    var response = await http
        .put(
          Uri.parse(url),
          headers: await authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _timeoutResponse);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .put(
            Uri.parse(url),
            headers: await authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout, onTimeout: _timeoutResponse);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  static Future<http.Response> delete(String url) async {
    var response = await http
        .delete(Uri.parse(url), headers: await authHeaders())
        .timeout(_timeout, onTimeout: _timeoutResponse);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .delete(Uri.parse(url), headers: await authHeaders())
          .timeout(_timeout, onTimeout: _timeoutResponse);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }
}
