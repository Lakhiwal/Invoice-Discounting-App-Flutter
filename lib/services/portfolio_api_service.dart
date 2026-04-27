import 'dart:convert';

import 'package:invoice_discounting_app/services/api_client.dart';
import 'package:invoice_discounting_app/services/cache_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PortfolioApiService — Portfolio, Invoices, Investments
// ═══════════════════════════════════════════════════════════════════════════════

/// Cursor pagination result for invoice lists.
class InvoicePage {
  const InvoicePage({
    required this.items,
    required this.nextCursor,
    this.isFromCache = false,
  });

  const InvoicePage.empty()
      : items = const [],
        nextCursor = null,
        isFromCache = false;
  final List<Map<String, dynamic>> items;
  final String? nextCursor;
  final bool isFromCache;
  bool get hasMore => nextCursor != null;
}

class PortfolioApiService {
  static String get _base => ApiClient.baseUrl;

  // ── Portfolio ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getPortfolio({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
    String type = 'all',
    bool? isSecondary,
  }) async {
    final cacheKey = 'portfolio_data_${type}_${isSecondary}_${page}_$limit';

    if (!forceRefresh && page == 1) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return cached['data'] as Map<String, dynamic>;
    }

    try {
      var url = '$_base/portfolio/?page=$page&limit=$limit&type=$type';
      if (isSecondary != null) url += '&is_secondary=$isSecondary';
      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (page == 1) {
          await CacheService.save(cacheKey, data);
        }
        return data;
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (page == 1) {
        final cached = CacheService.get(cacheKey);
        if (cached != null) return cached['data'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getReceivableStatement({
    String? asOnDate,
    bool forceRefresh = false,
  }) async {
    try {
      var url = '$_base/portfolio/receivable-statement/';
      if (asOnDate != null) url += '?as_on_date=$asOnDate';
      final response = await ApiClient.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Invoices (cursor pagination) ──────────────────────────────────────────

  static Future<InvoicePage> getInvoicesCursor({
    String? afterCursor,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'invoices_${afterCursor ?? "first"}_$limit';

    if (forceRefresh && afterCursor == null) {
      await CacheService.clear(cacheKey);
    }

    if (!forceRefresh && afterCursor == null) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) {
        final data = cached['data'] as Map<String, dynamic>;
        final rawList =
            (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
        final nextCursor = data['next_cursor'] as String?;
        return InvoicePage(
          items: rawList,
          nextCursor: nextCursor,
          isFromCache: true,
        );
      }
    }

    try {
      final uri = afterCursor != null
          ? '$_base/invoices/?after=${Uri.encodeComponent(afterCursor)}&limit=$limit'
          : '$_base/invoices/?limit=$limit';

      final response = await ApiClient.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (afterCursor == null) {
          await CacheService.save(cacheKey, data);
        }
        final rawList =
            (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
        final nextCursor = data['next_cursor'] as String?;
        return InvoicePage(items: rawList, nextCursor: nextCursor);
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (afterCursor == null) {
        final cached = CacheService.get(cacheKey);
        if (cached != null) {
          final data = cached['data'] as Map<String, dynamic>;
          final rawList =
              (data['results'] as List? ?? []).cast<Map<String, dynamic>>();
          final nextCursor = data['next_cursor'] as String?;
          return InvoicePage(
            items: rawList,
            nextCursor: nextCursor,
            isFromCache: true,
          );
        }
      }
    }

    return const InvoicePage.empty();
  }

  /// Legacy offset-based method — kept for backward compatibility.
  static Future<List<dynamic>> getInvoices({
    int page = 1,
    int limit = 50,
    bool forceRefresh = false,
    String? status,
    bool unfundedOnly = false,
  }) async {
    final cacheKey =
        'invoices_page_${page}_${limit}_${status ?? "default"}_$unfundedOnly';
    if (forceRefresh && page == 1) {
      await CacheService.clear(cacheKey);
    }
    if (!forceRefresh && page == 1) {
      final cached = CacheService.get(cacheKey);
      if (cached != null) return (cached['data'] as List?) ?? [];
    }

    try {
      var url = '$_base/invoices/?page=$page&limit=$limit';
      if (status != null) url += '&status=$status';
      if (unfundedOnly) url += '&unfunded_only=true';
      final response = await ApiClient.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        var results = <dynamic>[];
        if (decoded is Map) {
          results =
              (decoded['results'] as List?) ?? (decoded['data'] as List?) ?? [];
        } else if (decoded is List) {
          results = decoded;
        }

        if (page == 1 && results.isNotEmpty) {
          await CacheService.save(cacheKey, results);
        }
        return results;
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (page == 1) {
        final cached = CacheService.get(cacheKey);
        if (cached != null) return (cached['data'] as List?) ?? [];
      }
    }

    return [];
  }

  static Future<Map<String, dynamic>?> getInvoiceDetail(int id) async {
    try {
      final response = await ApiClient.get('$_base/invoices/$id/');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}
    return null;
  }

  // ── Invest ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> invest(
    int invoiceId,
    double amount,
  ) async {
    try {
      final response = await ApiClient.post('$_base/invest/', {
        'invoice_id': invoiceId,
        'amount': amount.toString(),
      });

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {
          'success': true,
          ...data,
        };
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

  static Future<Map<String, dynamic>?> calculateInvestment(
    int invoiceId,
    double amount,
  ) async {
    try {
      final response = await ApiClient.post(
        '$_base/invest/calculate/',
        {
          'invoice_id': invoiceId,
          'amount': amount.toString(),
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {}

    return null;
  }
}
