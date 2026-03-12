import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:invoice_discounting_app/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/secure_storage_service.dart';

/// Thrown when the user is unauthenticated and refresh failed.
/// UI should catch this and navigate to login.
class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException(
      [this.message = 'Session expired. Please log in again.']);

  @override
  String toString() => message;
}

// ── Cursor pagination result ──────────────────────────────────────────────────
// Returned by getInvoices() so the caller knows the next cursor
// and whether more pages exist — without needing to inspect raw maps.

class InvoicePage {
  /// The invoice maps for this page (raw, as returned by the API).
  final List<Map<String, dynamic>> items;

  /// Opaque cursor to pass as `after=` on the next request.
  /// Null when this is the last page.
  final String? nextCursor;

  /// True when the server signals there are no more pages.
  bool get hasMore => nextCursor != null;

  const InvoicePage({required this.items, required this.nextCursor});

  /// Empty result — used in catch blocks.
  const InvoicePage.empty()
      : items = const [],
        nextCursor = null;
}

class ApiService {
  static const String baseUrl = "${AppConfig.baseUrl}/api";

  // ============================================================
  // TIMEOUT
  // ============================================================

  static const _timeout = Duration(seconds: 10);

  // FIX #30: use 408 (Request Timeout) — all public methods check for 408
  // to detect timeouts. The old 599 was never matched, so every timeout
  // silently fell through to the generic error path.
  static http.Response _timeoutResponse() => http.Response(
        '{"error":"Request timed out. Check your connection."}',
        408,
      );

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static Future<void> _saveAccessToken(String access) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
  }

  static Future<Map<String, dynamic>?> calculateInvestment(
    int invoiceId,
    double amount,
  ) async {
    try {
      final response = await _post(
        '$baseUrl/invest/calculate/',
        {
          'invoice_id': invoiceId,
          'amount': amount.toString(),
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}

    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
    // SecureStorage uses Android Keystore which can deadlock on Samsung devices.
    // Wrap in a timeout so a Keystore hang never blocks the UI thread.
    await SecureStorageService.clearCredentials()
        .timeout(const Duration(seconds: 3), onTimeout: () {
      debugPrint('SecureStorage.clearCredentials timed out — skipping');
    });
  }

  /// Called by the biometric login path after loading the stored refresh token
  /// into SharedPreferences. Returns true if a new access token was obtained.
  /// This is the safe alternative to replaying a stored password (fix #5).
  static Future<bool> refreshWithStoredToken() => _refreshAccessToken();

  static Future<bool> isLoggedIn() async {
    final token = await _getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  static Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
  static Future<bool>? _refreshFuture;
  // ============================================================
  // TOKEN REFRESH
  // ============================================================

  static Future<bool> _refreshAccessToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performRefresh();

    final result = await _refreshFuture!;

    _refreshFuture = null;

    return result;
  }

  static Future<bool> _performRefresh() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh/'),
            headers: _publicHeaders,
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access'];

        if (newAccess != null) {
          await _saveAccessToken(newAccess);
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  // ============================================================
  // SMART HTTP METHODS (auto-refresh on 401/403)
  // ============================================================

  static Future<http.Response> _get(String url) async {
    var response = await http
        .get(
          Uri.parse(url),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => _timeoutResponse());

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .get(
            Uri.parse(url),
            headers: await _authHeaders(),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  static Future<http.Response> _put(
    String url,
    Map<String, dynamic> body,
  ) async {
    var response = await http
        .put(
          Uri.parse(url),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: () => _timeoutResponse());

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .put(
            Uri.parse(url),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  static Future<http.Response> _post(
    String url,
    Map<String, dynamic> body,
  ) async {
    var response = await http
        .post(
          Uri.parse(url),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: () => _timeoutResponse());

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .post(
            Uri.parse(url),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  // FIX #8: _delete helper with the same auto-refresh-on-401 pattern used
  // by _get / _post / _put. Previously deleteBankAccount called http.delete
  // directly, so an expired token was never refreshed — it just failed.
  static Future<http.Response> _delete(String url) async {
    var response = await http
        .delete(
          Uri.parse(url),
          headers: await _authHeaders(),
        )
        .timeout(_timeout, onTimeout: () => _timeoutResponse());

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) throw const UnauthorizedException();

      response = await http
          .delete(
            Uri.parse(url),
            headers: await _authHeaders(),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

// ============================================================
// AUTH — LOGIN
// ============================================================

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login/'),
            headers: _publicHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await _saveTokens(data['access'], data['refresh']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// AUTH — REGISTRATION
// ============================================================

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String mobile,
    required String panNumber,
    required String password,
    required String userType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/'),
            headers: _publicHeaders,
            body: jsonEncode({
              'name': name,
              'email': email,
              'mobile': mobile,
              'pan_number': panNumber,
              'password': password,
              'user_type': userType,
            }),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': data['message'] ?? 'OTP sent.'};
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Registration failed. Please try again.',
      };
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// AUTH — OTP VERIFICATION
// ============================================================

  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-otp/'),
            headers: _publicHeaders,
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Email verified.'
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Invalid OTP. Please try again.',
      };
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// AUTH — RESEND OTP
// ============================================================

  static Future<Map<String, dynamic>> resendOtp({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/resend-otp/'),
            headers: _publicHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'OTP resent.'};
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Failed to resend OTP.',
      };
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// AUTH — FORGOT / RESET PASSWORD
// ============================================================

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/forgot-password/'),
            headers: _publicHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'OTP sent.'};
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Failed to send OTP.',
      };
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-password/'),
            headers: _publicHeaders,
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'new_password': newPassword,
            }),
          )
          .timeout(_timeout, onTimeout: () => _timeoutResponse());

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password reset successfully.',
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Password reset failed.',
      };
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final response = await _post(
        '$baseUrl/auth/change-password/',
        {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password updated successfully',
        };
      }

      return {
        'success': false,
        'error': data['error'] ?? 'Failed to change password',
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'error': 'Session expired. Please log in again.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// PROFILE
// ============================================================

  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _get('$baseUrl/profile/');
      if (response.statusCode == 200) return jsonDecode(response.body);
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) return jsonDecode(data);
    return null;
  }

// ============================================================
// MARKETPLACE  —  CURSOR PAGINATION
// ============================================================
//
// WHY CURSOR INSTEAD OF OFFSET:
// Offset pagination (?page=2&limit=40) breaks on live marketplaces.
// If 3 invoices are funded between your first and second page load,
// page 2 skips 3 items entirely — users never see them.
// Cursor pagination uses the ID of the last seen item as a stable
// anchor, so new items being inserted never cause drift.
//
// BACKEND REQUIREMENT:
// Your Django view must support ?after=<id>&limit=<n> and return:
//   { "results": [...], "next_cursor": "<id_or_null>" }
//
// If your backend still uses offset, the Flutter side is ready —
// just add cursor support to the Django view and it works immediately.
// The old getInvoices(page:, limit:) signature is kept as a fallback
// below so nothing else in the app breaks during the migration.
//
// ─────────────────────────────────────────────────────────────

  /// Fetch one page of invoices using cursor pagination.
  ///
  /// [afterCursor] — pass the `nextCursor` from the previous [InvoicePage].
  ///                 Null fetches the first page.
  /// [limit]       — items per page (default 40).
  ///
  /// Returns an [InvoicePage] with the items and the cursor for the next page.
  /// [InvoicePage.hasMore] is false when there are no more pages.
  static Future<InvoicePage> getInvoicesCursor({
    String? afterCursor,
    int limit = 50,
  }) async {
    try {
// Build URL — include cursor only when fetching page 2+
      final uri = afterCursor != null
          ? '$baseUrl/invoices/?after=${Uri.encodeComponent(afterCursor)}&limit=$limit'
          : '$baseUrl/invoices/?limit=$limit';

      final response = await _get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

// Backend returns { "results": [...], "next_cursor": "abc" | null }
        final rawList =
            (data['results'] as List? ?? []).cast<Map<String, dynamic>>();

// next_cursor is null when this is the last page
        final nextCursor = data['next_cursor'] as String?;

        return InvoicePage(items: rawList, nextCursor: nextCursor);
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}

    return const InvoicePage.empty();
  }

  /// Legacy offset-based method — kept so existing callers (portfolio,
  /// analytics, etc.) continue to compile without changes.
  /// Migrate call sites to [getInvoicesCursor] one screen at a time.
  static Future<List<dynamic>> getInvoices({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _get('$baseUrl/invoices/?page=$page&limit=$limit');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'] ?? [];
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}

    return [];
  }

  static Future<Map<String, dynamic>?> getInvoiceDetail(int id) async {
    try {
      final response = await _get('$baseUrl/invoices/$id/');
      if (response.statusCode == 200) return jsonDecode(response.body);
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return null;
  }


  //=============================================================
// WEBVIEW TOKENS
// ============================================================

  static Future<Map<String, dynamic>> createWebviewToken() async {
    final response = await _post('$baseUrl/auth/webview-token/', {});
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

// ============================================================
// INVEST
// ============================================================

  static Future<Map<String, dynamic>> invest(
      int invoiceId, double amount) async {
    try {
      final response = await _post('$baseUrl/invest/', {
        'invoice_id': invoiceId,
        'amount': amount.toString(),
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      }
      return {'success': false, 'error': data['error'] ?? 'Investment failed'};
    } on UnauthorizedException {
      return {
        'success': false,
        'error': 'Session expired. Please log in again.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// PORTFOLIO
// ============================================================

  static Future<Map<String, dynamic>?> getPortfolio() async {
    try {
      final response = await _get('$baseUrl/portfolio/');
      if (response.statusCode == 200) return jsonDecode(response.body);
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return null;
  }

// ============================================================
// WALLET
// ============================================================

  static Future<Map<String, dynamic>?> getWallet() async {
    try {
      final response = await _get('$baseUrl/wallet/');
      if (response.statusCode == 200) return jsonDecode(response.body);
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return null;
  }

  static Future<void> addFunds(double amount, String paymentMethod) async {
    try {
      final response = await _post('$baseUrl/wallet/add/', {
        'amount': amount.toString(),
        'payment_method': paymentMethod,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to add funds');
      }
    } on UnauthorizedException {
      throw Exception('Session expired. Please log in again.');
    } on SocketException {
      throw Exception('No internet connection');
    }
  }

  static Future<void> withdrawFunds(double amount) async {
    try {
      final response = await _post('$baseUrl/wallet/withdraw/', {
        'amount': amount.toString(),
      });

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to withdraw funds');
      }
    } on UnauthorizedException {
      throw Exception('Session expired. Please log in again.');
    } on SocketException {
      throw Exception('No internet connection');
    }
  }

// ============================================================
// FCM TOKEN REGISTRATION
// ============================================================

  static String? _lastRegisteredToken;

  static Future<void> registerFcmToken(String token) async {
    if (token.isEmpty || token == _lastRegisteredToken) return;

    try {
      await _post('$baseUrl/device/register/', {'fcm_token': token});
      _lastRegisteredToken = token;
    } catch (e) {
      assert(() {
        debugPrint('FCM registration failed: $e');
        return true;
      }());
    }
  }

// ============================================================
// QUIET HOURS
// ============================================================

  static Future<void> updateQuietHours(TimeOfDay? start, TimeOfDay? end) async {
    try {
      final startStr = start != null
          ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
          : null;
      final endStr = end != null
          ? '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
          : null;

      await _post('$baseUrl/notifications/quiet-hours/', {
        'quiet_start': startStr,
        'quiet_end': endStr,
      });

      debugPrint('✅ Quiet hours synced: start=$startStr end=$endStr');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ updateQuietHours failed: $e');
      rethrow;
    }
  }

// ============================================================
// BANK ACCOUNTS
// ============================================================

  static Future<List<Map<String, dynamic>>> getBankAccounts() async {
    try {
      final response = await _get('$baseUrl/bank-accounts/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String beneficiaryName,
    required String branchAddress,
    bool isPrimary = false,
  }) async {
    try {
      final response = await _post('$baseUrl/bank-accounts/', {
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'beneficiary_name': beneficiaryName,
        'branch_address': branchAddress,
        'is_primary': isPrimary,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) return {'success': true, ...data};
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to add account'
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'error': 'Session expired. Please log in again.'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> setPrimaryBankAccount(
      int accountId) async {
    try {
      final response =
          await _post('$baseUrl/bank-accounts/$accountId/set-primary/', {});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to set primary'
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'error': 'Session expired. Please log in again.'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteBankAccount(int accountId) async {
    try {
// FIX #8: use _delete() so an expired token is refreshed automatically
// instead of failing silently with a 401.
      final response = await _delete('$baseUrl/bank-accounts/$accountId/');
      if (response.statusCode == 204) return {'success': true};
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to delete account'
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'error': 'Session expired. Please log in again.'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

// ============================================================
// NOMINEE
// ============================================================

  static Future<Map<String, dynamic>?> getNominee() async {
    try {
      final response = await _get('$baseUrl/nominee/');
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 404) return null; // no nominee yet
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> saveNominee({
    required String name,
    required int age,
    required String gender,
    required String relationship,
    String guardianName = '',
    String address = '',
  }) async {
    try {
// Use PUT — backend upserts (creates or updates) the single nominee record
      final response = await _put('$baseUrl/nominee/', {
        'name': name,
        'age': age,
        'gender': gender,
        'relationship': relationship,
        'guardian_name': guardianName,
        'address': address,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...data};
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to save nominee'
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'error': 'Session expired. Please log in again.'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
