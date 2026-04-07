import 'dart:convert';
import 'dart:io';

import 'api_client.dart';
import 'cache_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WalletApiService — Wallet, Payments, Transactions
// ═══════════════════════════════════════════════════════════════════════════════

class WalletApiService {
  static String get _base => ApiClient.baseUrl;

  // ── Wallet ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getWallet(
      {bool forceRefresh = false}) async {
    const cacheKey = 'wallet_data';

    if (!forceRefresh) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }

    try {
      final response = await ApiClient.get('$_base/wallet/');
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

  static Future<void> addFunds(double amount, String paymentMethod) async {
    try {
      final response = await ApiClient.post('$_base/wallet/add/', {
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
      final response = await ApiClient.post('$_base/wallet/withdraw/', {
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

  static Future<Map<String, dynamic>> getWalletHistory(
      {bool forceRefresh = false}) async {
    const cacheKey = 'wallet_history';
    if (!forceRefresh) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }

    try {
      final response = await ApiClient.get('$_base/wallet/history/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await CacheService.save(cacheKey, data);
        return data;
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to load history'
      };
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // ── Payments (Cashfree) ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createCashfreeOrder(
      double amount) async {
    try {
      final response =
          await ApiClient.post('$_base/payments/cashfree/create-order/', {
        'amount': amount.toStringAsFixed(2),
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to create order'
      };
    } on UnauthorizedException {
      return {'success': false, 'error': 'Session expired'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyCashfreePayment({
    required String orderId,
  }) async {
    try {
      final response =
          await ApiClient.post('$_base/payments/cashfree/verify/', {
        'order_id': orderId,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      return {
        'success': false,
        'status': data['status'] ?? 'failed',
        'error': data['error'] ?? 'Verification failed',
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'status': 'failed',
        'error': 'Session expired'
      };
    } catch (e) {
      return {
        'success': false,
        'status': 'pending',
        'error': 'Connection error — wallet will update shortly'
      };
    }
  }

  // ── Payments (Razorpay) ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createRazorpayOrder(
      double amount) async {
    try {
      final response = await ApiClient.post('$_base/payments/create-order/', {
        'amount': amount.toString(),
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      }

      return {'success': false, 'error': data['error']};
    } on UnauthorizedException {
      return {'success': false, 'error': 'Session expired'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      final response = await ApiClient.post('$_base/payments/verify/', {
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data;
      }

      return {
        'success': false,
        'status': data['status'] ?? 'failed',
        'error': data['error'] ?? 'Verification failed',
      };
    } on UnauthorizedException {
      return {
        'success': false,
        'status': 'failed',
        'error': 'Session expired',
      };
    } catch (e) {
      return {
        'success': false,
        'status': 'pending',
        'error': 'Connection error — wallet will update shortly',
      };
    }
  }
}
