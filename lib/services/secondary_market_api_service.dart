import 'dart:convert';
import 'package:invoice_discounting_app/services/api_client.dart';

class SecondaryMarketApiService {
  static String get _base => ApiClient.baseUrl;

  /// Fetch active secondary market listings
  static Future<List<Map<String, dynamic>>> fetchListings() async {
    try {
      final response = await ApiClient.get('$_base/secondary/listings/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        return results?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Request to sell a stake
  static Future<Map<String, dynamic>> requestExit(int fundingId) async {
    try {
      final response = await ApiClient.post('$_base/secondary/request/', {
        'funding_id': fundingId,
      });
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] as String? ??
          data['error'] as String? ??
          'Request failed';

      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'message': message,
        'data': data,
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Complete a purchase
  static Future<Map<String, dynamic>> buyListing(int listingId) async {
    try {
      final response = await ApiClient.post('$_base/secondary/buy/', {
        'listing_id': listingId,
      });
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] as String? ??
          data['error'] as String? ??
          'Purchase failed';

      return {
        'success': response.statusCode == 200,
        'message': message,
        'data': data,
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
