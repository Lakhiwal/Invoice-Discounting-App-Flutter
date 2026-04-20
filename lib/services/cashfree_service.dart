import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

/// Cashfree payment service — mirrors RazorpayService interface.
/// Usage:
///   final cashfree = CashfreeService();
///   cashfree.onSuccess = (orderId) { ... };
///   cashfree.onError = (error) { ... };
///   cashfree.openCheckout(
///     orderId: 'cf_xxx',
///     paymentSessionId: 'session_xxx',
///     environment: 'SANDBOX', // or 'PRODUCTION'
///   );
class CashfreeService {
  CashfreeService() {
    _gateway.setCallback(_onVerify, _onError);
  }

  /// Called on successful payment with the order ID.
  void Function(String orderId)? onSuccess;

  /// Called on payment failure with error message.
  void Function(String error)? onError;

  final _gateway = CFPaymentGatewayService();

  void _onVerify(String orderId) {
    debugPrint('Cashfree payment verified: $orderId');
    onSuccess?.call(orderId);
  }

  void _onError(CFErrorResponse error, String orderId) {
    debugPrint('Cashfree payment error: ${error.getMessage()} for $orderId');
    onError?.call(error.getMessage() ?? 'Payment failed');
  }

  /// Open Cashfree web checkout.
  ///
  /// [orderId] — the order ID from your backend (e.g., "cf_abc123def456")
  /// [paymentSessionId] — from create_cashfree_order API response
  /// [environment] — "SANDBOX" or "PRODUCTION"
  void openCheckout({
    required String orderId,
    required String paymentSessionId,
    String environment = 'SANDBOX',
  }) {
    try {
      final cfEnv = environment == 'PRODUCTION'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

      final session = CFSessionBuilder()
          .setEnvironment(cfEnv)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final webCheckout =
          CFWebCheckoutPaymentBuilder().setSession(session).build();

      _gateway.doPayment(webCheckout);
    } catch (e) {
      debugPrint('Cashfree checkout error: $e');
      onError?.call('Failed to open payment: $e');
    }
  }

  void dispose() {
    // No explicit dispose needed for Cashfree SDK
  }
}
