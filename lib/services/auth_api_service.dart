import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'secure_storage_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AuthApiService — Login, Register, OTP, Password, 2FA
// ═══════════════════════════════════════════════════════════════════════════════

class AuthApiService {
  static String get _base => ApiClient.baseUrl;

  // ── Login ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> check2FAStatus(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/auth/check-2fa/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'requires_2fa': false};
    } catch (_) {
      return {'requires_2fa': false};
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/auth/login/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

      if (response.statusCode == 408) {
        return {
          'success': false,
          'error': 'Request timed out. Check your connection.'
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['requires_2fa'] == true) {
          return {
            'success': false,
            '2fa_required': true,
            'pre_auth_token': data['pre_auth_token'],
          };
        }

        await ApiClient.saveTokens(data['access'], data['refresh']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        return {
          'success': true,
          'user': data['user'],
          'refresh': data['refresh'],
        };
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } on SocketException {
      return {'success': false, 'error': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // ── Registration ───────────────────────────────────────────────────────────

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
            Uri.parse('$_base/register/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({
              'name': name,
              'email': email,
              'mobile': mobile,
              'pan_number': panNumber,
              'password': password,
              'user_type': userType,
            }),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

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

  // ── OTP ────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/verify-otp/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

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

  static Future<Map<String, dynamic>> resendOtp({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/resend-otp/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

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

  // ── Password ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/forgot-password/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

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
            Uri.parse('$_base/reset-password/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

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
      final response = await ApiClient.post(
        '$_base/auth/change-password/',
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

  // ── 2FA / Security Shield ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> get2FAStatus() async {
    try {
      final response = await ApiClient.get('$_base/auth/2fa/status/');
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      return {
        'success': false,
        'error': 'Failed to fetch status (${response.statusCode})'
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> setup2FA() async {
    try {
      final response = await ApiClient.post('$_base/auth/2fa/setup/', {});
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      try {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'error': data['error'] ??
              data['detail'] ??
              'Setup failed (${response.statusCode})'
        };
      } catch (_) {
        return {
          'success': false,
          'error': 'Setup failed (${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> activate2FA(String token) async {
    try {
      final response =
          await ApiClient.post('$_base/auth/2fa/activate/', {'token': token});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'error': data['error'] ?? 'Activation failed'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> disable2FA(String token) async {
    try {
      final response =
          await ApiClient.post('$_base/auth/2fa/disable/', {'token': token});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Deactivation failed'
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> verify2FALogin(
      String preAuthToken, String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/auth/2fa/verify/'),
            headers: ApiClient.publicHeaders,
            body: jsonEncode({
              'pre_auth_token': preAuthToken,
              'token': token,
            }),
          )
          .timeout(const Duration(seconds: 10),
              onTimeout: () => http.Response(
                    '{"error":"Request timed out. Check your connection."}',
                    408,
                  ));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access'] != null) {
        await ApiClient.saveTokens(data['access'], data['refresh']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(data['user']));
        return {
          'success': true,
          'user': data['user'],
          'refresh': data['refresh']
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Verification failed'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }

  // ── Logout / Session ───────────────────────────────────────────────────────

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await SecureStorageService.clearAll().timeout(const Duration(seconds: 3),
        onTimeout: () {
      debugPrint('SecureStorage.clearAll timed out — skipping');
    });
  }

  static Future<bool> isLoggedIn() async {
    final token = await ApiClient.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> refreshWithStoredToken() =>
      ApiClient.refreshAccessToken();

  static Future<Map<String, dynamic>> createWebviewToken() async {
    final response = await ApiClient.post('$_base/auth/webview-token/', {});
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
