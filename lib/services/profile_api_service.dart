import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'cache_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ProfileApiService — Profile, Bank Accounts, Nominee, Profile Picture
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileApiService {
  static String get _base => ApiClient.baseUrl;

  // ── Profile ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile(
      {bool forceRefresh = false}) async {
    const cacheKey = 'profile_data';
    if (!forceRefresh) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }

    try {
      final response = await ApiClient.get('$_base/profile/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await CacheService.save(cacheKey, data);
        return data;
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) return jsonDecode(data);
    return null;
  }

  // ── Profile Picture ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadProfilePicture(
      File imageFile) async {
    final token = await ApiClient.getAccessToken();
    if (token == null) return {'error': 'Not authenticated'};

    try {
      final uri = Uri.parse('$_base/profile/picture/');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
          'picture',
          imageFile.path,
          contentType: MediaType(
              'image', imageFile.path.endsWith('.png') ? 'png' : 'jpeg'),
        ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'url': data['url']};
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['error'] ?? 'Upload failed'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteProfilePicture() async {
    final token = await ApiClient.getAccessToken();
    if (token == null) return {'error': 'Not authenticated'};

    try {
      final response = await http.delete(
        Uri.parse('$_base/profile/picture/delete/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['error'] ?? 'Failed to remove'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  // ── Bank Accounts ──────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getBankAccounts(
      {bool forceRefresh = false}) async {
    const cacheKey = 'bank_accounts';
    if (!forceRefresh) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) {
        return (cached['data'] as List).cast<Map<String, dynamic>>();
      }
    }

    try {
      final response = await ApiClient.get('$_base/bank-accounts/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final list = data.cast<Map<String, dynamic>>();
        await CacheService.save(cacheKey, list);
        return list;
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) {
        return (cached['data'] as List).cast<Map<String, dynamic>>();
      }
    }
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
      final response = await ApiClient.post('$_base/bank-accounts/', {
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
      final response = await ApiClient.post(
          '$_base/bank-accounts/$accountId/set-primary/', {});
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
      final response =
          await ApiClient.delete('$_base/bank-accounts/$accountId/');
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

  // ── Nominee ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getNominee(
      {bool forceRefresh = false}) async {
    const cacheKey = 'nominee_data';
    if (!forceRefresh) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }

    try {
      final response = await ApiClient.get('$_base/nominee/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await CacheService.save(cacheKey, data);
        return data;
      }
      if (response.statusCode == 404) return null;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }
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
      final response = await ApiClient.put('$_base/nominee/', {
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
