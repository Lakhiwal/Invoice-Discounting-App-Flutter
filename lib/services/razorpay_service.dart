import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  late Razorpay _razorpay;

  /// Called with (paymentId, orderId, signature) on success.
  Function(String paymentId, String orderId, String signature)? onSuccess;
  Function(String error)? onError;

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
  }

  void openCheckout({
    required String orderId,
    required double amount,
    required String key,
    String name = "Finworks360",
    String description = "Add Funds",
  }) {
    var options = {
      'key': key,
      'amount': (amount * 100).toInt(),
      'order_id': orderId,
      'name': name,
      'description': description,
      'prefill': {'contact': '', 'email': ''},
    };

    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(
      response.paymentId ?? '',
      response.orderId ?? '',
      response.signature ?? '',
    );
  }

  void _handleError(PaymentFailureResponse response) {
    onError?.call(response.message ?? 'Payment failed');
  }

  void _handleExternal(ExternalWalletResponse response) {}

  void dispose() {
    _razorpay.clear();
  }
}