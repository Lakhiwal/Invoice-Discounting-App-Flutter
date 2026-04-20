import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/services/notification_service.dart';

class DeepLinkTestUtil {
  /// Simulates a notification tap for a new invoice.
  static void simulateNewInvoice(int invoiceId) {
    debugPrint('🧪 Simulating Deep Link: new_invoice, ID: $invoiceId');
    NotificationService.handleDeepLink({
      'type': 'new_invoice',
      'invoice_id': invoiceId.toString(),
    });
  }

  /// Simulates a notification tap for a generic system alert.
  static void simulateSystemAlert(String message) {
    debugPrint('🧪 Simulating Deep Link: system_alert');
    NotificationService.handleDeepLink({
      'type': 'system',
      'body': message,
    });
  }
}
