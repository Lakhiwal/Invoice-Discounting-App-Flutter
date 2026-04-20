import 'package:flutter/material.dart';

import 'package:invoice_discounting_app/services/api_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NotificationApiService — FCM Token Registration, Quiet Hours
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationApiService {
  static String get _base => ApiClient.baseUrl;

  static String? _lastRegisteredToken;

  static Future<void> registerFcmToken(String token) async {
    if (token.isEmpty || token == _lastRegisteredToken) return;

    try {
      await ApiClient.post('$_base/device/register/', {'fcm_token': token});
      _lastRegisteredToken = token;
    } catch (e) {
      assert(() {
        debugPrint('FCM registration failed: $e');
        return true;
      }());
    }
  }

  static Future<void> updateQuietHours(TimeOfDay? start, TimeOfDay? end) async {
    try {
      final startStr = start != null
          ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
          : null;
      final endStr = end != null
          ? '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
          : null;

      await ApiClient.post('$_base/notifications/quiet-hours/', {
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
}
